import Foundation
import AVFoundation
import ScreenCaptureKit

@available(macOS 13.0, *)
class AudioCaptureManager: NSObject, ObservableObject {
    static let shared = AudioCaptureManager()
    
    private var stream: SCStream?
    private var audioEngine: AVAudioEngine?
    private var isRecording = false
    
    // Callbacks for audio data
    var onSystemAudioData: ((Data) -> Void)?
    var onMicrophoneAudioData: ((Data) -> Void)?
    
    // Audio format for Deepgram (Linear PCM, 16-bit, 48kHz, 1 channel)
    private let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48000, channels: 1, interleaved: true)!
    
    override private init() {
        super.init()
    }
    
    func startCapture() async throws {
        guard !isRecording else { return }
        
        // 1. Request Permissions
        if #available(macOS 14.0, *) {
            guard await AVAudioApplication.requestRecordPermission() else {
                print("Microphone permission denied")
                return
            }
        } else {
             switch AVCaptureDevice.authorizationStatus(for: .audio) {
             case .authorized:
                 break
             case .notDetermined:
                 await AVCaptureDevice.requestAccess(for: .audio)
             default:
                 print("Microphone permission denied")
                 return
             }
        }

        try await startSystemAudioCapture()
        // try startMicrophoneCapture() // Disabled by user request
        
        isRecording = true
    }
    
    func stopCapture() {
        stream?.stopCapture()
        stream = nil
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        
        isRecording = false
    }
    
    private func startSystemAudioCapture() async throws {
        // Get available content
        let content = try await SCShareableContent.current
        
        guard let display = content.displays.first else { return }
        
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.capturesAudio = true // Redundant but explicit
        // config.capturesVideo = false // Default is true, but we only add audio output so video shouldn't be processed?
        // Actually, if we don't add a video output, SCStream might still capture it internally.
        // There isn't a direct 'capturesVideo = false' property in early versions, but we can try setting width/height to small?
        // Or just rely on not adding a video output.
        // Wait, SCStreamConfiguration DOES have properties to control what is captured.
        // But for audio-only, we just ensure we only add audio output.
        // However, the "purple icon" in menu bar indicates screen recording. This is unavoidable with SCK.
        
        config.excludesCurrentProcessAudio = true
        config.excludesCurrentProcessAudio = true 
        config.sampleRate = 48000
        config.channelCount = 1
        
        stream = SCStream(filter: filter, configuration: config, delegate: nil)
        
        // Add stream output
        try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global(qos: .userInitiated))
        
        try await stream?.startCapture()
    }
    
    private func startMicrophoneCapture() throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap on input node
        // We need to convert input format to our target format (48kHz, Int16, Mono)
        
        let converter = AVAudioConverter(from: inputFormat, to: targetFormat)!
        
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] (buffer, time) in
            guard let self = self else { return }
            
            // Convert buffer
            let inputCallback: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            
            let targetFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * (self.targetFormat.sampleRate / inputFormat.sampleRate))
            
            if let convertedBuffer = AVAudioPCMBuffer(pcmFormat: self.targetFormat, frameCapacity: targetFrameCapacity) {
                var error: NSError? = nil
                converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputCallback)
                
                if let data = self.extractData(from: convertedBuffer) {
                    self.onMicrophoneAudioData?(data)
                }
            }
        }
        
        try engine.start()
        self.audioEngine = engine
    }
    
    private func extractData(from buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.int16ChannelData else { return nil }
        let channelPointer = channelData[0]
        let frameCount = Int(buffer.frameLength)
        let dataLen = frameCount * 2 // 16-bit = 2 bytes
        return Data(bytes: channelPointer, count: dataLen)
    }
}

@available(macOS 13.0, *)
extension AudioCaptureManager: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        
        // Convert CMSampleBuffer to raw Data
        guard let data = extractData(from: sampleBuffer) else { return }
        
        // Send to Deepgram
        onSystemAudioData?(data)
    }
    
    private func extractData(from sampleBuffer: CMSampleBuffer) -> Data? {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return nil }
        
        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        
        guard CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer) == kCMBlockBufferNoErr,
              let pointer = dataPointer else {
            return nil
        }
        
        // Deepgram expects raw PCM. 
        // SCK usually provides Float32. We might need to convert to Int16 if we promised that in the URL.
        // The URL in DeepgramService says `encoding=linear16`.
        // So we MUST convert Float32 -> Int16.
        
        // Check format
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee else {
            return nil
        }
        
        // If it's already Int16, just return data
        if asbd.mFormatFlags & kAudioFormatFlagIsFloat == 0 && asbd.mBitsPerChannel == 16 {
             return Data(bytes: pointer, count: length)
        }
        
        // If Float32, convert
        if asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0 && asbd.mBitsPerChannel == 32 {
            return convertFloat32ToInt16(pointer, length: length)
        }
        
        return nil
    }
    
    private func convertFloat32ToInt16(_ pointer: UnsafeMutablePointer<Int8>, length: Int) -> Data {
        let floatCount = length / 4
        let floatPointer = pointer.withMemoryRebound(to: Float.self, capacity: floatCount) { $0 }
        
        var int16Data = Data(count: floatCount * 2)
        int16Data.withUnsafeMutableBytes { buffer in
            let int16Pointer = buffer.bindMemory(to: Int16.self).baseAddress!
            
            // Simple conversion with clipping
            // Accelerate framework would be faster but this is simpler for now
            for i in 0..<floatCount {
                let floatVal = floatPointer[i]
                let clamped = max(-1.0, min(1.0, floatVal))
                let intVal = Int16(clamped * 32767.0)
                int16Pointer[i] = intVal
            }
        }
        
        return int16Data
    }
}

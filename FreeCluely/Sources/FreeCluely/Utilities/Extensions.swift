import AppKit
import CoreGraphics

extension CGImage {
    func resize(maxDimension: CGFloat) -> CGImage? {
        let width = CGFloat(self.width)
        let height = CGFloat(self.height)
        
        let aspectRatio = width / height
        var newWidth: CGFloat
        var newHeight: CGFloat
        
        if width > height {
            newWidth = min(width, maxDimension)
            newHeight = newWidth / aspectRatio
        } else {
            newHeight = min(height, maxDimension)
            newWidth = newHeight * aspectRatio
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: Int(newWidth),
            height: Int(newHeight),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        
        context?.interpolationQuality = .high
        context?.draw(self, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        
        return context?.makeImage()
    }
}

extension CGImage {
    func jpegData(compressionQuality: CGFloat) -> Data? {
        let bitmapRep = NSBitmapImageRep(cgImage: self)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
}

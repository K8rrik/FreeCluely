import SwiftUI
import AppKit

struct ResizeHandleView: NSViewRepresentable {
    func makeNSView(context: Context) -> ResizeHandleNSView {
        return ResizeHandleNSView()
    }
    
    func updateNSView(_ nsView: ResizeHandleNSView, context: Context) {}
}

class ResizeHandleNSView: NSView {
    private var trackingArea: NSTrackingArea?
    private var initialLocation: NSPoint?
    private var initialFrame: NSRect?
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let trackingArea = self.trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .cursorUpdate]
        trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    override func cursorUpdate(with event: NSEvent) {
        // There isn't a public diagonal resize cursor, so we use a close approximation
        // or try to use a private one if we were daring (but we won't).
        // NSCursor.crosshair is distinct.
        // NSCursor.resizeLeftRight is standard for edges.
        // Let's use a custom cursor or just the arrow if we can't find a better one.
        // Actually, _windowResizeNorthWestSouthEastCursor is the one, but it's private.
        // We will use resizeUpDown as it implies vertical movement, or just the arrow.
        // A common workaround is using the diagonal resize cursor image.
        // For now, let's use `crosshair` to indicate precision/action.
        NSCursor.arrow.set()
    }
    
    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }
        initialLocation = NSEvent.mouseLocation
        initialFrame = window.frame
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let window = self.window,
              let initialLocation = initialLocation,
              let initialFrame = initialFrame else { return }
        
        let currentLocation = NSEvent.mouseLocation
        let deltaX = currentLocation.x - initialLocation.x
        let deltaY = currentLocation.y - initialLocation.y
        
        var newFrame = initialFrame
        
        // Dragging right (positive deltaX) increases width
        newFrame.size.width += deltaX
        
        // Dragging down (negative deltaY) increases height and decreases origin.y
        // We want the top edge to stay fixed.
        // Top = Origin.y + Height.
        // NewTop = (Origin.y + deltaY) + (Height - deltaY) = Origin.y + Height. Correct.
        
        newFrame.size.height -= deltaY
        newFrame.origin.y += deltaY
        
        // Minimum size constraints
        let minWidth: CGFloat = 200
        let minHeight: CGFloat = 100
        
        if newFrame.size.width < minWidth {
            newFrame.size.width = minWidth
        }
        
        if newFrame.size.height < minHeight {
            // If we hit min height, we need to adjust origin.y back so the top doesn't move?
            // If we just clamp height, origin.y is still shifted by deltaY.
            // We need to recalculate origin.y based on the clamped height.
            // Top = initialFrame.maxY
            // NewOriginY = Top - clampedHeight
            
            let top = initialFrame.maxY
            newFrame.size.height = minHeight
            newFrame.origin.y = top - minHeight
        }
        
        window.setFrame(newFrame, display: true)
    }
    
    override func mouseUp(with event: NSEvent) {
        initialLocation = nil
        initialFrame = nil
        // Reset cursor if needed, though cursorUpdate handles it usually
        window?.invalidateCursorRects(for: self)
    }
}

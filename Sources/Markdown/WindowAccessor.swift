import SwiftUI
import AppKit

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                // Restore saved frame if available
                if let savedFrame = AppearancePreference.shared.hostWindowFrame {
                    // Basic check to ensure valid frame dimensions
                    if savedFrame.width > 0 && savedFrame.height > 0 {
                        window.setFrame(savedFrame, display: true)
                    }
                }
                
                // Start observing changes
                context.coordinator.monitor(window: window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        var window: NSWindow?
        var observers: [NSObjectProtocol] = []
        
        deinit {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
        }
        
        func monitor(window: NSWindow) {
            self.window = window
            
            // Clean up old observers
            observers.forEach { NotificationCenter.default.removeObserver($0) }
            observers.removeAll()
            
            let center = NotificationCenter.default
            
            observers.append(center.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.saveFrame() }
            })

            observers.append(center.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.saveFrame() }
            })
        }
        
        @MainActor
        private func saveFrame() {
            guard let window = window else { return }
            AppearancePreference.shared.hostWindowFrame = window.frame
        }
    }
}

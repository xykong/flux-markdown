import Foundation
import Cocoa

/// Manages persistence of the last opened file for restoration after updates
public class UpdateRestorationManager {
    public static let shared = UpdateRestorationManager()
    
    private let lastOpenedFileKey = "lastOpenedFilePath"
    private let pendingUpdateKey = "pendingUpdate"
    
    private let store: UserDefaults
    
    private init() {
        // Main-app-only storage — no need for cross-process sharing
        self.store = UserDefaults.standard
    }
    
    /// Save the path of the currently open file
    public func saveLastOpenedFile(url: URL) {
        store.set(url.path, forKey: lastOpenedFileKey)
        store.synchronize()
        print("✅ Saved last opened file: \(url.path)")
    }
    
    /// Get the path of the last opened file
    public func getLastOpenedFile() -> URL? {
        guard let path = store.string(forKey: lastOpenedFileKey) else { return nil }
        let url = URL(fileURLWithPath: path)
        
        if FileManager.default.fileExists(atPath: path) {
            print("📁 Found last opened file: \(path)")
            return url
        } else {
            clearLastOpenedFile()
            return nil
        }
    }
    
    /// Clear the saved file path
    public func clearLastOpenedFile() {
        store.removeObject(forKey: lastOpenedFileKey)
        store.synchronize()
        print("🗑️ Cleared last opened file")
    }
    
    /// Mark that an update is pending (called before update starts)
    public func markUpdatePending() {
        store.set(true, forKey: pendingUpdateKey)
        store.synchronize()
        print("⏳ Update marked as pending")
    }
    
    /// Check if an update was pending (called after app restart)
    public func isUpdatePending() -> Bool {
        let pending = store.bool(forKey: pendingUpdateKey)
        if pending {
            print("🔄 Update was pending, will restore last file")
        }
        return pending
    }
    
    /// Clear the pending update flag
    public func clearUpdatePending() {
        store.removeObject(forKey: pendingUpdateKey)
        store.synchronize()
        print("✅ Cleared pending update flag")
    }
    
    /// Restore the last opened file (should be called on app startup after update)
    public func restoreLastOpenedFile() {
        guard isUpdatePending() else { return }
        
        defer { clearUpdatePending() }
        
        guard let fileURL = getLastOpenedFile() else {
            print("⚠️ No valid file to restore")
            return
        }
        
        print("🔄 Attempting to restore file after update...")
        
        // Schedule the file opening with a slight delay to ensure the app is fully launched
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            NSDocumentController.shared.openDocument(withContentsOf: fileURL, display: true) { _, _, error in
                if let error = error {
                    print("❌ Failed to restore document: \(error.localizedDescription)")
                    self?.clearLastOpenedFile()
                } else {
                    print("✅ Successfully restored document after update")
                }
            }
        }
    }
}

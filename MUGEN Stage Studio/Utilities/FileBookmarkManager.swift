import Foundation

/// Manages security-scoped bookmarks for persistent file access
class FileBookmarkManager {
    
    static let shared = FileBookmarkManager()
    
    private let bookmarkKey = "SavedFileBookmarks"
    
    private init() {}
    
    // MARK: - Save Bookmark
    
    /// Save a security-scoped bookmark for a URL
    /// - Parameters:
    ///   - url: The URL to bookmark
    ///   - identifier: A unique identifier for this bookmark
    func saveBookmark(for url: URL, identifier: String) throws {
        let bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        
        var bookmarks = loadBookmarks()
        bookmarks[identifier] = bookmarkData
        
        UserDefaults.standard.set(bookmarks, forKey: bookmarkKey)
    }
    
    // MARK: - Restore Bookmark
    
    /// Restore a URL from a saved bookmark
    /// - Parameter identifier: The identifier used when saving
    /// - Returns: The resolved URL, or nil if not found/invalid
    func restoreBookmark(for identifier: String) -> URL? {
        let bookmarks = loadBookmarks()
        
        guard let bookmarkData = bookmarks[identifier] else {
            return nil
        }
        
        var isStale = false
        
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                // Bookmark is stale, try to refresh it
                try? saveBookmark(for: url, identifier: identifier)
            }
            
            // Start accessing the security-scoped resource
            _ = url.startAccessingSecurityScopedResource()
            
            return url
        } catch {
            // Bookmark is invalid, remove it
            removeBookmark(for: identifier)
            return nil
        }
    }
    
    // MARK: - Remove Bookmark
    
    /// Remove a saved bookmark
    /// - Parameter identifier: The identifier of the bookmark to remove
    func removeBookmark(for identifier: String) {
        var bookmarks = loadBookmarks()
        bookmarks.removeValue(forKey: identifier)
        UserDefaults.standard.set(bookmarks, forKey: bookmarkKey)
    }
    
    // MARK: - Stop Accessing
    
    /// Stop accessing a security-scoped resource
    /// - Parameter url: The URL to stop accessing
    func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
    
    // MARK: - Private
    
    private func loadBookmarks() -> [String: Data] {
        return UserDefaults.standard.dictionary(forKey: bookmarkKey) as? [String: Data] ?? [:]
    }
}

// MARK: - Common Identifiers

extension FileBookmarkManager {
    
    static let lastExportFolder = "lastExportFolder"
    static let lastImportFolder = "lastImportFolder"
}

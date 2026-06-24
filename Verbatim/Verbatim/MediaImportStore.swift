import Foundation

enum MediaImportStore {
    static func localPlayableURL(for url: URL) throws -> URL {
#if os(iOS)
        let fileManager = FileManager.default
        let directory = try importedMediaDirectory()
        let standardizedDirectory = directory.standardizedFileURL.path
        let standardizedURL = url.standardizedFileURL

        if standardizedURL.path.hasPrefix(standardizedDirectory) {
            return standardizedURL
        }

        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let destination = uniqueDestination(for: url, in: directory)
        try fileManager.copyItem(at: url, to: destination)

        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableDestination = destination
        try? mutableDestination.setResourceValues(resourceValues)

        return destination
#else
        return url
#endif
    }

#if os(iOS)
    private static func importedMediaDirectory() throws -> URL {
        let directory = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("ImportedMedia", isDirectory: true)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func uniqueDestination(for url: URL, in directory: URL) -> URL {
        let fileManager = FileManager.default
        let baseName = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension
        let safeBaseName = sanitized(baseName).isEmpty ? "Media" : sanitized(baseName)
        var candidate = directory.appendingPathComponent(safeBaseName).appendingPathExtension(fileExtension)

        var suffix = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directory
                .appendingPathComponent("\(safeBaseName)-\(suffix)")
                .appendingPathExtension(fileExtension)
            suffix += 1
        }

        return candidate
    }

    private static func sanitized(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_()."))
        return String(name.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
#endif
}

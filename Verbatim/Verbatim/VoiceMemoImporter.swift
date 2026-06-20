import Foundation
import UniformTypeIdentifiers

#if os(macOS)
import AppKit

enum VoiceMemoImporter {
    static func chooseRecordings() -> [URL] {
        let panel = NSOpenPanel()
        panel.title = "Choose Voice Memos"
        panel.prompt = "Add"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.audio, .movie]

        if let voiceMemosURL = voiceMemosContainerURL() {
            panel.directoryURL = voiceMemosURL
        }

        return panel.runModal() == .OK ? panel.urls : []
    }

    private static func voiceMemosContainerURL() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appending(path: "Library/Group Containers/group.com.apple.VoiceMemos.shared"),
            home.appending(path: "Library/Group Containers/group.com.apple.VoiceMemos"),
            home.appending(path: "Library/Application Support/com.apple.voicememos")
        ]

        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
#endif

import Foundation
import AppKit
import PDFKit

/// Loads the user's resume, cover letter template, and outreach template from
/// ~/Library/Application Support/Pursuit/templates/, caching parsed text.
/// Handles the first-launch "locate your toolkit folder" flow.
@MainActor
final class TemplateLoader: ObservableObject {
    @Published private(set) var resumeText: String?
    @Published private(set) var coverLetterTemplate: String?
    @Published private(set) var outreachTemplate: String?
    @Published private(set) var isConfigured: Bool = false

    private let fileManager = FileManager.default
    private var profileID: UUID?

    private var templatesDirectory: URL {
        Self.templatesDirectory(forProfile: profileID)
    }

    private static func templatesDirectory(forProfile profileID: UUID?) -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var url = appSupport.appendingPathComponent("Pursuit", isDirectory: true)
        if let profileID {
            url = url.appendingPathComponent("profiles", isDirectory: true)
                .appendingPathComponent(profileID.uuidString, isDirectory: true)
        }
        return url.appendingPathComponent("templates", isDirectory: true)
    }

    private let supportedExtensions: Set<String> = ["txt", "md", "pdf", "rtf"]

    /// Points the loader at a given profile's own template folder and reloads
    /// from it. Pass `nil` only before a profile exists yet.
    func configure(profileID: UUID?) {
        self.profileID = profileID
        loadIfAvailable()
    }

    /// Reads whatever is already cached in the templates directory. Never throws -
    /// a missing or empty directory just leaves fields nil and `isConfigured` false.
    func loadIfAvailable() {
        guard let files = try? fileManager.contentsOfDirectory(at: templatesDirectory, includingPropertiesForKeys: nil) else {
            resumeText = nil
            coverLetterTemplate = nil
            outreachTemplate = nil
            isConfigured = false
            return
        }

        resumeText = firstMatch(files, keywords: ["resume", "cv"])
        coverLetterTemplate = firstMatch(files, keywords: ["cover_letter", "cover-letter", "coverletter", "cover letter"])
        outreachTemplate = firstMatch(files, keywords: ["outreach", "cold_email", "cold-email"])

        isConfigured = resumeText != nil || coverLetterTemplate != nil || outreachTemplate != nil
    }

    private func firstMatch(_ files: [URL], keywords: [String]) -> String? {
        for url in files {
            guard supportedExtensions.contains(url.pathExtension.lowercased()) else { continue }
            let name = url.deletingPathExtension().lastPathComponent.lowercased()
            if keywords.contains(where: { name.contains($0) }) {
                return readText(from: url)
            }
        }
        return nil
    }

    private func readText(from url: URL) -> String? {
        switch url.pathExtension.lowercased() {
        case "pdf":
            return PDFDocument(url: url)?.string
        case "rtf":
            guard let data = try? Data(contentsOf: url) else { return nil }
            let attributed = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
            return attributed?.string
        default:
            return try? String(contentsOf: url, encoding: .utf8)
        }
    }

    /// Presents an NSOpenPanel for the user's toolkit folder (resume, cover
    /// letter template, outreach template) and copies matching files into
    /// Application Support/Pursuit/templates/. Returns true if anything was found.
    @discardableResult
    func promptForFolderAndImport() -> Bool {
        let panel = NSOpenPanel()
        panel.title = "Locate Your Toolkit Folder"
        panel.message = "Choose the folder containing your resume, cover letter template, and outreach template."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let sourceFolder = panel.url else { return false }
        return importFolder(from: sourceFolder)
    }

    @discardableResult
    func importFolder(from sourceFolder: URL) -> Bool {
        let accessed = sourceFolder.startAccessingSecurityScopedResource()
        defer { if accessed { sourceFolder.stopAccessingSecurityScopedResource() } }

        guard let files = try? fileManager.contentsOfDirectory(at: sourceFolder, includingPropertiesForKeys: nil) else {
            return false
        }

        try? fileManager.createDirectory(at: templatesDirectory, withIntermediateDirectories: true)

        var importedAny = false
        for source in files where supportedExtensions.contains(source.pathExtension.lowercased()) {
            let destination = templatesDirectory.appendingPathComponent(source.lastPathComponent)
            try? fileManager.removeItem(at: destination)
            if (try? fileManager.copyItem(at: source, to: destination)) != nil {
                importedAny = true
            }
        }

        loadIfAvailable()
        return importedAny
    }

    /// One-time migration: pre-multi-profile installs kept templates directly
    /// under Application Support/Pursuit/templates/. Move that folder into the
    /// first profile created on upgrade so existing users don't lose them.
    static func migrateLegacyTemplatesIfNeeded(toProfile profileID: UUID) {
        let fm = FileManager.default
        let legacy = templatesDirectory(forProfile: nil)
        let destination = templatesDirectory(forProfile: profileID)
        guard fm.fileExists(atPath: legacy.path), !fm.fileExists(atPath: destination.path) else { return }
        try? fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? fm.moveItem(at: legacy, to: destination)
    }

    /// Removes a deleted profile's template folder from disk.
    static func removeTemplates(forProfile profileID: UUID) {
        let dir = templatesDirectory(forProfile: profileID).deletingLastPathComponent()
        try? FileManager.default.removeItem(at: dir)
    }
}

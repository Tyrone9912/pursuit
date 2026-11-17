import Foundation
import SwiftData

/// AI-generated output for one `Application`, keyed loosely by `applicationID`
/// rather than a SwiftData relationship, matching the Phase 2 spec directly.
@Model
final class GeneratedContent {
    @Attribute(.unique) var id: UUID
    var applicationID: UUID
    var research: String
    var coverLetter: String
    var outreachSubject: String = ""
    var outreach: String
    var trackerNote: String
    var dateGenerated: Date
    /// Which backend actually produced this content, for display/debugging.
    var sourceRaw: String

    var source: ModelSource {
        get { ModelSource(rawValue: sourceRaw) ?? .claudeAPI }
        set { sourceRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        applicationID: UUID,
        research: String = "",
        coverLetter: String = "",
        outreachSubject: String = "",
        outreach: String = "",
        trackerNote: String = "",
        dateGenerated: Date = .now,
        source: ModelSource = .claudeAPI
    ) {
        self.id = id
        self.applicationID = applicationID
        self.research = research
        self.coverLetter = coverLetter
        self.outreachSubject = outreachSubject
        self.outreach = outreach
        self.trackerNote = trackerNote
        self.dateGenerated = dateGenerated
        self.sourceRaw = source.rawValue
    }
}

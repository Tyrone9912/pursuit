import SwiftUI
import SwiftData

enum ApplicationStatus: String, CaseIterable, Identifiable, Codable {
    case preparing = "Preparing application"
    case appliedDirect = "Applied: direct link"
    case outreachSent = "Outreach sent"
    case recruiterScreen = "Recruiter screen"
    case hiringManagerCall = "Hiring manager call"
    case offer = "Offer"
    case noResponse = "No response"

    var id: String { rawValue }

    /// Matches the sidebar `.status-dot` color mapping in the design spec.
    var dotColor: Color {
        switch self {
        case .preparing: return Theme.amber
        case .appliedDirect, .outreachSent, .recruiterScreen: return Theme.blue
        case .hiringManagerCall, .offer: return Theme.green
        case .noResponse: return Theme.text3
        }
    }
}

/// The persisted application-tracker record. Backed by SwiftData (which sits on
/// top of SQLite), fulfilling the original "SQLite for the application tracker" spec.
@Model
final class Application {
    @Attribute(.unique) var id: UUID
    /// The `Profile` this application belongs to. Defaults to a random UUID
    /// on decode so existing pre-multi-profile stores migrate without a
    /// crash; `AppViewModel` reassigns any orphaned rows to the default
    /// profile on first launch after the upgrade.
    var profileID: UUID = UUID()
    var company: String
    var role: String
    var salary: String?
    var salaryMissing: Bool
    var statusRaw: String
    var dateAdded: Date
    var jdText: String
    var applyLink: String
    var followUpDate: Date?
    var notes: String
    var statusDetail: String?

    var status: ApplicationStatus {
        get { ApplicationStatus(rawValue: statusRaw) ?? .preparing }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        profileID: UUID,
        company: String,
        role: String,
        salary: String? = nil,
        salaryMissing: Bool = true,
        status: ApplicationStatus = .preparing,
        dateAdded: Date = .now,
        jdText: String = "",
        applyLink: String = "",
        followUpDate: Date? = nil,
        notes: String = "",
        statusDetail: String? = nil
    ) {
        self.id = id
        self.profileID = profileID
        self.company = company
        self.role = role
        self.salary = salary
        self.salaryMissing = salaryMissing
        self.statusRaw = status.rawValue
        self.dateAdded = dateAdded
        self.jdText = jdText
        self.applyLink = applyLink
        self.followUpDate = followUpDate
        self.notes = notes
        self.statusDetail = statusDetail
    }
}

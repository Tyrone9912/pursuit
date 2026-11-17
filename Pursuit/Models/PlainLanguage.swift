import Foundation

extension String {
    /// Enforces the house style for AI-generated copy (cover letter, outreach,
    /// research): plain language, no em dashes. Applied at render time so it
    /// stays in force once the real generation pipeline replaces `DemoContent`.
    var plainLanguage: String {
        replacingOccurrences(of: " — ", with: ", ")
            .replacingOccurrences(of: "—", with: ",")
            .replacingOccurrences(of: " – ", with: ", ")
            .replacingOccurrences(of: "–", with: "-")
    }
}

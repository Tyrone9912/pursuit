import Foundation

/// Parsed shape of `GeneratedContent.research`, which is generated as a single
/// JSON string (see `ModelManager.research`) so the model field stays a plain
/// `String` while the UI can still render distinct sections.
struct ResearchBrief: Decodable {
    let overview: String
    let news: [String]
    let culture: [String]
    let techStack: [String]
    let hiringTrends: [String]
    let whyThisRole: String

    enum CodingKeys: String, CodingKey {
        case overview, news, culture
        case techStack = "tech_stack"
        case hiringTrends = "hiring_trends"
        case whyThisRole = "why_this_role"
    }

    static func parse(_ raw: String) -> ResearchBrief? {
        guard let jsonSubstring = raw.extractingJSONObject() else { return nil }
        return try? JSONDecoder().decode(ResearchBrief.self, from: Data(jsonSubstring.utf8))
    }
}

/// Parsed shape of `GeneratedContent.coverLetter`, generated with explicit
/// `FIRST PARAGRAPH:` / `COMPANY SENTENCE:` markers (see
/// `AppViewModel.coverLetterPrompt`) so the two customized spots can be
/// highlighted distinctly in the full assembled letter.
struct CoverLetterParts {
    let firstParagraph: String
    let companySentence: String

    static func parse(_ raw: String) -> CoverLetterParts? {
        guard
            let firstRange = raw.range(of: "FIRST PARAGRAPH:"),
            let sentenceRange = raw.range(of: "COMPANY SENTENCE:")
        else {
            return nil
        }
        let firstParagraph = String(raw[firstRange.upperBound..<sentenceRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let companySentence = String(raw[sentenceRange.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !firstParagraph.isEmpty, !companySentence.isEmpty else { return nil }
        return CoverLetterParts(firstParagraph: firstParagraph, companySentence: companySentence)
    }
}

/// Parsed shape of a raw `SUBJECT:` / `MESSAGE:` marked outreach response,
/// split at generation time into `GeneratedContent.outreachSubject` / `.outreach`.
struct OutreachParts {
    let subject: String
    let message: String

    static func parse(_ raw: String) -> OutreachParts? {
        guard
            let subjectRange = raw.range(of: "SUBJECT:"),
            let messageRange = raw.range(of: "MESSAGE:")
        else {
            return nil
        }
        let subject = String(raw[subjectRange.upperBound..<messageRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let message = String(raw[messageRange.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !subject.isEmpty, !message.isEmpty else { return nil }
        return OutreachParts(subject: subject, message: message)
    }
}

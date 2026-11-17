import Foundation

struct ParsedJD {
    var company: String
    var role: String
    var salary: String?
    var salaryMissing: Bool { salary == nil }
}

/// Extracts company, role, and salary range from raw job-description text.
/// Salary is tried with regex first since compensation strings are highly
/// patterned; company/role regex is a much weaker heuristic, so any gap - or a
/// salary miss, in case regex under-matched an unusual format - is filled by a
/// single Claude fallback call that asks for strict JSON.
enum JDParser {
    static func parse(text: String, modelManager: ModelManager) async -> ParsedJD {
        let regexSalary = extractSalary(from: text)
        let regexCompany = extractCompany(from: text)
        let regexRole = extractRole(from: text)

        let needsFallback = regexCompany == nil || regexRole == nil || regexSalary == nil
        guard needsFallback else {
            return ParsedJD(company: regexCompany!, role: regexRole!, salary: regexSalary)
        }

        if let fallback = try? await claudeFallback(text: text, modelManager: modelManager) {
            return ParsedJD(
                company: regexCompany ?? fallback.company ?? "Unknown Company",
                role: regexRole ?? fallback.role ?? "Unknown Role",
                salary: regexSalary ?? fallback.salary
            )
        }

        return ParsedJD(
            company: regexCompany ?? "Unknown Company",
            role: regexRole ?? "Unknown Role",
            salary: regexSalary
        )
    }

    // MARK: - Regex heuristics

    private static func extractSalary(from text: String) -> String? {
        let patterns = [
            #"\$\s?\d{2,3}(?:,\d{3}|[kK])\s?(?:-|–|to)\s?\$?\s?\d{2,3}(?:,\d{3}|[kK])(?:\s?(?:\/\s?(?:yr|year)|per\s?year|annually))?"#,
            #"\$\s?\d{2,3},\d{3}(?:\s?(?:\/\s?(?:yr|year)|per\s?year|annually))"#,
            #"up to \$\s?\d{2,3}(?:,\d{3}|[kK])"#,
        ]
        for pattern in patterns {
            if let match = firstMatch(pattern: pattern, in: text, caseInsensitive: true) {
                return match.trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private static func extractCompany(from text: String) -> String? {
        let patterns = [
            #"^([A-Z][A-Za-z0-9&.,' ]{1,40}?) is (?:seeking|looking for|hiring)"#,
            #"[Jj]oin ([A-Z][A-Za-z0-9&.,' ]{1,40}?) as"#,
            #"at ([A-Z][A-Za-z0-9&.,' ]{1,40}?)[.,!]"#,
        ]
        for pattern in patterns {
            if let match = firstCapturedGroup(pattern: pattern, in: text) {
                return match.trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private static func extractRole(from text: String) -> String? {
        let patterns = [
            #"seeking an? ([A-Z][A-Za-z0-9/&, ]{2,50}?) to"#,
            #"hiring an? ([A-Z][A-Za-z0-9/&, ]{2,50}?) to"#,
            #"[Rr]ole:\s*([A-Za-z0-9/&, ]{2,50})"#,
            #"[Tt]itle:\s*([A-Za-z0-9/&, ]{2,50})"#,
        ]
        for pattern in patterns {
            if let match = firstCapturedGroup(pattern: pattern, in: text) {
                return match.trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private static func firstMatch(pattern: String, in text: String, caseInsensitive: Bool = false) -> String? {
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range), let r = Range(match.range, in: text) else {
            return nil
        }
        return String(text[r])
    }

    private static func firstCapturedGroup(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard
            let match = regex.firstMatch(in: text, options: [], range: range),
            match.numberOfRanges > 1,
            let r = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[r])
    }

    // MARK: - Claude fallback

    private struct FallbackResult: Decodable {
        let company: String?
        let role: String?
        let salary: String?
    }

    private static func claudeFallback(text: String, modelManager: ModelManager) async throws -> FallbackResult {
        let prompt = """
        You extract structured data from job descriptions. Read the job description below and respond with ONLY a JSON object, no markdown fences, no commentary, matching exactly this shape:
        {"company": string, "role": string, "salary": string or null}

        Rules:
        - "salary" is the compensation range or figure exactly as stated in the text (e.g. "$120,000-$150,000"), or null if no compensation is mentioned anywhere in the text.
        - Use plain language. Do not use em dashes.

        Job description:
        \"\"\"
        \(text)
        \"\"\"
        """
        let raw = try await modelManager.generate(prompt: prompt)
        guard let jsonSubstring = raw.extractingJSONObject() else {
            throw ModelManagerError.claudeRequestFailed("No JSON object found in fallback response")
        }
        return try JSONDecoder().decode(FallbackResult.self, from: Data(jsonSubstring.utf8))
    }
}

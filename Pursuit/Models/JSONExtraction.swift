import Foundation

extension String {
    /// Pulls the first `{...}` substring out of a model response that may
    /// include stray commentary or markdown fences around the JSON payload.
    func extractingJSONObject() -> String? {
        guard let start = firstIndex(of: "{"), let end = lastIndex(of: "}"), start < end else {
            return nil
        }
        return String(self[start...end])
    }
}

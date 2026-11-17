import Foundation

enum ModelSource: String, Codable {
    case claudeAPI = "claudeAPI"
    case ollama = "ollama"
}

enum ModelManagerError: LocalizedError {
    case noAPIKey
    case claudeRequestFailed(String)
    case ollamaUnavailable
    case allSourcesFailed(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "No Claude API key configured."
        case .claudeRequestFailed(let detail): return "Claude API request failed: \(detail)"
        case .ollamaUnavailable: return "Local ollama fallback is not reachable."
        case .allSourcesFailed(let detail): return "Generation failed on every available source: \(detail)"
        }
    }
}

/// Routes generation requests to the Claude API and falls back to a local
/// ollama model transparently when the API is unreachable. Exposes a single
/// `generate(prompt:)` entry point per the Phase 2 spec; `research(company:role:)`
/// is a thin wrapper that additionally enables Claude's web search tool (Claude
/// API only - the spec calls for local fallback to cover cover-letter/outreach
/// generation only, "no web search").
@MainActor
final class ModelManager: ObservableObject {
    /// Claude Sonnet tier, current generation as of this build. The user asked
    /// for "claude-sonnet-4-5 or latest available" - claude-sonnet-4-5 has been
    /// superseded, so this uses the current Sonnet-tier model id instead.
    private let claudeModel = "claude-sonnet-5"
    private let claudeEndpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let anthropicVersion = "2023-06-01"

    /// Adjust to whatever model you've pulled locally (`ollama pull llama3.2`).
    private let ollamaModel = "llama3.2"
    private let ollamaGenerateEndpoint = URL(string: "http://127.0.0.1:11434/api/generate")!
    private let ollamaTagsEndpoint = URL(string: "http://127.0.0.1:11434/api/tags")!

    @Published private(set) var activeSource: ModelSource = .claudeAPI
    @Published private(set) var claudeReachable: Bool = false
    @Published private(set) var ollamaReachable: Bool = false

    private var apiKey: String? {
        if let env = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !env.isEmpty {
            return env
        }
        if let stored = UserDefaults.standard.string(forKey: "AnthropicAPIKey"), !stored.isEmpty {
            return stored
        }
        return nil
    }

    /// Pings both backends once (e.g. on launch) to set the status pill without
    /// spending a full generation call. `generate` still self-heals per-request
    /// regardless of what this last observed.
    func checkAvailability() async {
        claudeReachable = apiKey != nil
        ollamaReachable = await pingOllama()
        activeSource = claudeReachable ? .claudeAPI : (ollamaReachable ? .ollama : .claudeAPI)
    }

    private func pingOllama() async -> Bool {
        var request = URLRequest(url: ollamaTagsEndpoint)
        request.timeoutInterval = 2
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    /// Plain-text generation with automatic Claude -> ollama fallback.
    func generate(prompt: String, systemPrompt: String? = nil) async throws -> String {
        if apiKey != nil {
            do {
                let text = try await callClaude(prompt: prompt, systemPrompt: systemPrompt, tools: nil)
                activeSource = .claudeAPI
                claudeReachable = true
                return text
            } catch {
                claudeReachable = false
                // fall through to ollama
            }
        }

        do {
            let text = try await callOllama(prompt: prompt, systemPrompt: systemPrompt)
            activeSource = .ollama
            ollamaReachable = true
            return text
        } catch {
            ollamaReachable = false
            throw ModelManagerError.allSourcesFailed("Claude API and local ollama both failed. \(error.localizedDescription)")
        }
    }

    /// Company research via Claude's web search tool. No ollama equivalent
    /// exists (no web access locally), so this only ever runs against Claude.
    func research(company: String, role: String) async throws -> String {
        guard apiKey != nil else {
            throw ModelManagerError.noAPIKey
        }
        let prompt = """
        Research the company "\(company)" for someone preparing a job application for the role "\(role)". Use web search to find current, real information.

        When you are done searching, respond with ONLY a JSON object as your final message, no markdown fences, no commentary before or after it, matching exactly this shape:
        {
          "overview": string,
          "news": [string, ...],
          "culture": [string, ...],
          "tech_stack": [string, ...],
          "hiring_trends": [string, ...],
          "why_this_role": string
        }

        Rules:
        - "overview" is a 2-3 sentence company overview: industry, size, and what they do.
        - "news", "culture", "tech_stack", and "hiring_trends" are each 1-3 short bullet-length strings. If you find nothing reliable for a category, return an empty array for it rather than guessing.
        - "why_this_role" is a short paragraph on why this specific role matters at this company right now, and what pain points it likely addresses.
        - Plain language throughout. Do not use em dashes.
        """
        do {
            let text = try await callClaude(prompt: prompt, systemPrompt: nil, tools: [Self.webSearchTool])
            activeSource = .claudeAPI
            claudeReachable = true
            return text
        } catch {
            claudeReachable = false
            throw ModelManagerError.claudeRequestFailed(error.localizedDescription)
        }
    }

    private static let webSearchTool: [String: Any] = [
        "type": "web_search_20260209",
        "name": "web_search",
        "max_uses": 4,
    ]

    // MARK: - Claude API

    private func callClaude(prompt: String, systemPrompt: String?, tools: [[String: Any]]?, retriesRemaining: Int = 1) async throws -> String {
        guard let apiKey else { throw ModelManagerError.noAPIKey }

        var body: [String: Any] = [
            "model": claudeModel,
            "max_tokens": 2000,
            "messages": [["role": "user", "content": prompt]],
            "output_config": ["effort": tools == nil ? "low" : "medium"],
        ]
        if let systemPrompt {
            body["system"] = systemPrompt
        }
        if let tools {
            body["tools"] = tools
        }

        var request = URLRequest(url: claudeEndpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ModelManagerError.claudeRequestFailed("No HTTP response")
        }

        if http.statusCode == 429 || http.statusCode >= 500, retriesRemaining > 0 {
            try await Task.sleep(nanoseconds: 800_000_000)
            return try await callClaude(prompt: prompt, systemPrompt: systemPrompt, tools: tools, retriesRemaining: retriesRemaining - 1)
        }

        guard http.statusCode == 200 else {
            let bodyText = String(data: data, encoding: .utf8) ?? "unknown error"
            throw ModelManagerError.claudeRequestFailed("HTTP \(http.statusCode): \(bodyText)")
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = json["content"] as? [[String: Any]]
        else {
            throw ModelManagerError.claudeRequestFailed("Unrecognized response shape")
        }

        let text = content
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined(separator: "\n")

        guard !text.isEmpty else {
            throw ModelManagerError.claudeRequestFailed("Empty response text")
        }
        return text
    }

    // MARK: - Ollama fallback

    private func callOllama(prompt: String, systemPrompt: String?) async throws -> String {
        var fullPrompt = prompt
        if let systemPrompt {
            fullPrompt = "\(systemPrompt)\n\n\(prompt)"
        }

        let body: [String: Any] = [
            "model": ollamaModel,
            "prompt": fullPrompt,
            "stream": false,
        ]

        var request = URLRequest(url: ollamaGenerateEndpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ModelManagerError.ollamaUnavailable
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let text = json["response"] as? String,
            !text.isEmpty
        else {
            throw ModelManagerError.ollamaUnavailable
        }
        return text
    }
}

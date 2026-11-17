import SwiftUI
import SwiftData

enum CenterPaneState: Equatable {
    case empty
    case processing
    case result
}

struct ProcessingStep: Identifiable {
    let id = UUID()
    let label: String
    let detail: String
    var isVisible: Bool = false
    var isDone: Bool = false
    var isFailed: Bool = false
}

/// Owns application state for the three-panel layout and drives the JD ->
/// parse -> research -> cover letter -> outreach pipeline against `ModelManager`,
/// persisting results with SwiftData.
@MainActor
final class AppViewModel: ObservableObject {
    let modelContext: ModelContext
    @Published var modelManager = ModelManager()
    @Published var templateLoader = TemplateLoader()

    @Published var profiles: [Profile] = []
    @Published var currentProfileID: UUID?

    @Published var applications: [Application] = []
    @Published var generatedContentByApplication: [UUID: GeneratedContent] = [:]
    @Published var selectedApplicationID: UUID?
    @Published var searchText: String = ""

    @Published var centerState: CenterPaneState = .empty
    @Published var isDropTargeted: Bool = false
    @Published var droppedText: String = ""
    @Published var processingSteps: [ProcessingStep] = []
    @Published var pipelineError: String?

    private static let currentProfileDefaultsKey = "CurrentProfileID"

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadProfiles()
        refreshApplications()
        templateLoader.configure(profileID: currentProfileID)
        Task { await modelManager.checkAvailability() }
    }

    var currentProfile: Profile? {
        profiles.first { $0.id == currentProfileID }
    }

    var selectedApplication: Application? {
        applications.first { $0.id == selectedApplicationID }
    }

    var selectedGeneratedContent: GeneratedContent? {
        guard let id = selectedApplicationID else { return nil }
        return generatedContentByApplication[id]
    }

    var filteredApplications: [Application] {
        guard !searchText.isEmpty else { return applications }
        return applications.filter {
            $0.company.localizedCaseInsensitiveContains(searchText) ||
            $0.role.localizedCaseInsensitiveContains(searchText)
        }
    }

    var appliedCount: Int {
        applications.filter { $0.status != .preparing }.count
    }

    var remainingCount: Int {
        applications.filter { $0.status == .preparing }.count
    }

    func refreshApplications() {
        guard let currentProfileID else {
            applications = []
            generatedContentByApplication = [:]
            return
        }

        let appDescriptor = FetchDescriptor<Application>(
            predicate: #Predicate { $0.profileID == currentProfileID },
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
        )
        applications = (try? modelContext.fetch(appDescriptor)) ?? []

        let ownIDs = Set(applications.map(\.id))
        let contentDescriptor = FetchDescriptor<GeneratedContent>()
        let allContent = (try? modelContext.fetch(contentDescriptor)) ?? []
        generatedContentByApplication = Dictionary(
            allContent.filter { ownIDs.contains($0.applicationID) }.map { ($0.applicationID, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
    }

    // MARK: - Profiles

    /// Loads all profiles, creating a "Default" one on first run (or migrating
    /// a pre-multi-profile install into it), restores the last-active profile,
    /// and reassigns any applications that predate profiles to it.
    private func loadProfiles() {
        refreshProfilesList()

        if profiles.isEmpty {
            let profile = Profile(name: "Default")
            modelContext.insert(profile)
            try? modelContext.save()
            profiles = [profile]
            TemplateLoader.migrateLegacyTemplatesIfNeeded(toProfile: profile.id)
        }

        let storedID = UserDefaults.standard.string(forKey: Self.currentProfileDefaultsKey).flatMap(UUID.init(uuidString:))
        currentProfileID = profiles.first { $0.id == storedID }?.id ?? profiles.first?.id

        reassignOrphanedApplications()
    }

    private func refreshProfilesList() {
        let descriptor = FetchDescriptor<Profile>(sortBy: [SortDescriptor(\.createdAt)])
        profiles = (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Applications persisted before this profile field existed decode with a
    /// random `profileID` that matches nothing; fold them into the default profile.
    private func reassignOrphanedApplications() {
        guard let defaultID = currentProfileID else { return }
        let knownIDs = Set(profiles.map(\.id))
        let descriptor = FetchDescriptor<Application>()
        guard let all = try? modelContext.fetch(descriptor) else { return }

        var changed = false
        for app in all where !knownIDs.contains(app.profileID) {
            app.profileID = defaultID
            changed = true
        }
        if changed { try? modelContext.save() }
    }

    func switchProfile(_ profile: Profile) {
        guard profile.id != currentProfileID else { return }
        currentProfileID = profile.id
        UserDefaults.standard.set(profile.id.uuidString, forKey: Self.currentProfileDefaultsKey)
        reset()
        refreshApplications()
        templateLoader.configure(profileID: profile.id)
    }

    @discardableResult
    func addProfile(name: String) -> Profile {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = Profile(name: trimmed.isEmpty ? "New Profile" : trimmed)
        modelContext.insert(profile)
        try? modelContext.save()
        refreshProfilesList()
        switchProfile(profile)
        return profile
    }

    func renameProfile(_ profile: Profile, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        profile.name = trimmed
        try? modelContext.save()
        refreshProfilesList()
    }

    /// Deletes a profile along with all of its applications and generated
    /// content. Refuses to delete the last remaining profile.
    func deleteProfile(_ profile: Profile) {
        guard profiles.count > 1 else { return }
        let targetID = profile.id

        let appDescriptor = FetchDescriptor<Application>(predicate: #Predicate<Application> { $0.profileID == targetID })
        if let apps = try? modelContext.fetch(appDescriptor) {
            for app in apps {
                let appID = app.id
                let contentDescriptor = FetchDescriptor<GeneratedContent>(predicate: #Predicate<GeneratedContent> { $0.applicationID == appID })
                (try? modelContext.fetch(contentDescriptor))?.forEach { modelContext.delete($0) }
                modelContext.delete(app)
            }
        }
        modelContext.delete(profile)
        try? modelContext.save()
        TemplateLoader.removeTemplates(forProfile: targetID)

        refreshProfilesList()
        if currentProfileID == targetID {
            currentProfileID = nil
            if let next = profiles.first { switchProfile(next) }
        } else {
            refreshApplications()
        }
    }

    func acceptDrop(text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Task { await runPipeline(jdText: text) }
    }

    func reset() {
        withAnimation(.easeOut) {
            centerState = .empty
            droppedText = ""
            processingSteps = []
            pipelineError = nil
            selectedApplicationID = nil
        }
    }

    /// Selecting a sidebar item loads its stored JD and results (if any) into
    /// the center/detail panes, rather than just highlighting the row.
    func selectApplication(_ application: Application) {
        selectedApplicationID = application.id
        droppedText = application.jdText
        pipelineError = nil
        if generatedContentByApplication[application.id] != nil {
            processingSteps = [
                ProcessingStep(label: "Parsed", detail: "role, company, and salary", isVisible: true, isDone: true),
                ProcessingStep(label: "Researched", detail: "company background, news, and pain points", isVisible: true, isDone: true),
                ProcessingStep(label: "Cover letter", detail: "opening paragraph and company-specific sentence", isVisible: true, isDone: true),
                ProcessingStep(label: "Outreach", detail: "cold outreach message drafted", isVisible: true, isDone: true),
            ]
            withAnimation(.easeOut) { centerState = .result }
        } else {
            processingSteps = []
            withAnimation(.easeOut) { centerState = .empty }
        }
    }

    func saveEdits(to application: Application) {
        try? modelContext.save()
        refreshApplications()
    }

    // MARK: - Pipeline

    private func runPipeline(jdText: String) async {
        guard let profileID = currentProfileID else { return }
        pipelineError = nil
        droppedText = jdText
        centerState = .processing

        var steps = [
            ProcessingStep(label: "Parsed", detail: "extracting role, company, and salary"),
            ProcessingStep(label: "Researched", detail: "company background, news, and pain points"),
            ProcessingStep(label: "Cover letter", detail: "opening paragraph and company-specific sentence"),
            ProcessingStep(label: "Outreach", detail: "cold outreach message drafted"),
        ]
        processingSteps = steps

        let application = Application(profileID: profileID, company: "Parsing…", role: "", jdText: jdText)
        modelContext.insert(application)
        try? modelContext.save()
        refreshApplications()
        selectedApplicationID = application.id

        func markDone(_ index: Int) {
            steps[index].isVisible = true
            steps[index].isDone = true
            withAnimation(.easeOut(duration: 0.25)) { processingSteps = steps }
        }
        func markFailed(_ index: Int) {
            steps[index].isVisible = true
            steps[index].isFailed = true
            withAnimation(.easeOut(duration: 0.25)) { processingSteps = steps }
        }

        // Step 1: parse
        let parsed = await JDParser.parse(text: jdText, modelManager: modelManager)
        application.company = parsed.company
        application.role = parsed.role
        application.salary = parsed.salary
        application.salaryMissing = parsed.salaryMissing
        try? modelContext.save()
        refreshApplications()
        markDone(0)

        // Step 2: research
        let research: String
        do {
            research = try await modelManager.research(company: parsed.company, role: parsed.role)
            markDone(1)
        } catch {
            research = "Research unavailable right now. \(error.localizedDescription)"
            markFailed(1)
        }

        // Step 3: cover letter
        let coverLetter: String
        do {
            coverLetter = try await modelManager.generate(prompt: coverLetterPrompt(parsed: parsed, jdText: jdText, research: research))
            markDone(2)
        } catch {
            coverLetter = "Cover letter generation failed. \(error.localizedDescription)"
            markFailed(2)
        }

        // Step 4: outreach
        var outreachSubject = ""
        var outreachMessage: String
        do {
            let raw = try await modelManager.generate(prompt: outreachPrompt(parsed: parsed, jdText: jdText, research: research))
            if let parts = OutreachParts.parse(raw) {
                outreachSubject = parts.subject
                outreachMessage = parts.message
            } else {
                outreachSubject = "Regarding the \(parsed.role) role"
                outreachMessage = raw
            }
            markDone(3)
        } catch {
            outreachMessage = "Outreach generation failed. \(error.localizedDescription)"
            markFailed(3)
        }

        let trackerNote = trackerNote(for: parsed)
        let content = GeneratedContent(
            applicationID: application.id,
            research: research,
            coverLetter: coverLetter,
            outreachSubject: outreachSubject,
            outreach: outreachMessage,
            trackerNote: trackerNote,
            source: modelManager.activeSource
        )
        modelContext.insert(content)
        try? modelContext.save()
        refreshApplications()

        if steps.contains(where: { $0.isFailed }) {
            pipelineError = "Some steps fell back to placeholder text. Check the Claude API key and ollama status."
        }

        withAnimation(.easeOut) { centerState = .result }
    }

    private func coverLetterPrompt(parsed: ParsedJD, jdText: String, research: String) -> String {
        """
        Write the opening of a cover letter for this job seeker. Plain language, no em dashes, first person: one strong opening paragraph reacting to something specific in the job description, and one sentence specific to this company drawing on the research below.

        Respond with exactly this format, nothing else:
        FIRST PARAGRAPH:
        <the opening paragraph>
        COMPANY SENTENCE:
        <the one company-specific sentence>

        ROLE: \(parsed.role) at \(parsed.company)
        SALARY LISTED: \(parsed.salary ?? "not listed")

        JOB DESCRIPTION:
        \(jdText)

        COMPANY RESEARCH:
        \(research)

        CANDIDATE RESUME:
        \(templateLoader.resumeText ?? "No resume on file. Write generally but confidently.")

        CANDIDATE'S OWN COVER LETTER TEMPLATE (match this tone and voice):
        \(templateLoader.coverLetterTemplate ?? "No template on file. Use a direct, confident, first-person tone.")
        """
    }

    private func outreachPrompt(parsed: ParsedJD, jdText: String, research: String) -> String {
        """
        Write a short cold outreach message (for LinkedIn or email) from this job seeker to someone at the company, plus a subject line. Plain language, no em dashes, first person, message under 150 words, ending with a soft ask for 15 minutes.

        Respond with exactly this format, nothing else:
        SUBJECT:
        <a short subject line>
        MESSAGE:
        <the message body>

        ROLE: \(parsed.role) at \(parsed.company)

        JOB DESCRIPTION:
        \(jdText)

        COMPANY RESEARCH:
        \(research)

        CANDIDATE RESUME:
        \(templateLoader.resumeText ?? "No resume on file. Write generally but confidently.")

        CANDIDATE'S OUTREACH TEMPLATE (match this tone and voice):
        \(templateLoader.outreachTemplate ?? "No template on file. Use a direct, confident, first-person tone.")
        """
    }

    private func trackerNote(for parsed: ParsedJD) -> String {
        let salaryNote = parsed.salaryMissing ? "Salary not listed, flagged for follow up." : "Salary listed: \(parsed.salary ?? "")."
        return "Auto-generated by Pursuit for \(parsed.role) at \(parsed.company). \(salaryNote)"
    }
}

extension AppViewModel {
    /// In-memory-backed instance for SwiftUI previews only.
    static var preview: AppViewModel {
        let schema = Schema([Application.self, GeneratedContent.self, Profile.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        return AppViewModel(modelContext: container.mainContext)
    }
}

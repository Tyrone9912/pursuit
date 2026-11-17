import SwiftUI

private struct OutputSection<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label.uppercased())
                .font(Theme.Font.label())
                .foregroundStyle(Theme.text3)
                .tracking(0.8)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }
}

private struct CopyRow: View {
    let title: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Button(title) { copy() }
                .buttonStyle(PursuitButtonStyle(kind: .primary))
                .font(.system(size: 11.5, weight: .medium))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .overlay(alignment: .top) { Rectangle().fill(Theme.border).frame(height: 1) }
    }

    private func copy() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

private struct EmptyContentNote: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Theme.text3)
            .padding(14)
    }
}

/// A visually distinct block (left border + subtle tint, no bold) for a
/// customized excerpt sitting inside an otherwise plain letter/message.
private struct HighlightedBlock: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.text1)
            .lineSpacing(5)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accentBg)
            .overlay(alignment: .leading) {
                Rectangle().fill(Theme.accent).frame(width: 3)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Research

struct ResearchTabView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        Group {
            if let app = viewModel.selectedApplication {
                let brief = viewModel.selectedGeneratedContent.flatMap { ResearchBrief.parse($0.research) }
                VStack(spacing: 0) {
                    Text(app.company)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.text1)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }

                    if let brief {
                        OutputSection(label: "Company Overview") {
                            Text(brief.overview.plainLanguage)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Theme.text1)
                                .lineSpacing(5)
                        }

                        OutputSection(label: "Highlights") {
                            VStack(alignment: .leading, spacing: 6) {
                                bullets(brief.news, tag: "News")
                                bullets(brief.culture, tag: "Culture")
                                bullets(brief.techStack, tag: "Tech Stack")
                                bullets(brief.hiringTrends, tag: "Hiring")
                            }
                        }

                        OutputSection(label: "Why This Role") {
                            Text(brief.whyThisRole.plainLanguage)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Theme.text1)
                                .lineSpacing(5)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.accentBg)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.accentBorder, lineWidth: 1))
                        }
                    } else if let raw = viewModel.selectedGeneratedContent?.research {
                        OutputSection(label: "Research") {
                            Text(raw.plainLanguage)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Theme.text1)
                                .lineSpacing(5)
                        }
                    } else {
                        EmptyContentNote(text: "No research generated yet.")
                    }
                }
            } else {
                EmptyContentNote(text: "No research generated yet.")
            }
        }
    }

    @ViewBuilder
    private func bullets(_ items: [String], tag: String) -> some View {
        ForEach(items, id: \.self) { item in
            HStack(alignment: .top, spacing: 6) {
                Text("→").foregroundStyle(Theme.accent).fontWeight(.semibold)
                (Text(tag + ": ").fontWeight(.semibold).foregroundStyle(Theme.text2)
                    + Text(item.plainLanguage).foregroundStyle(Theme.text2))
            }
            .font(.system(size: 12))
        }
    }
}

// MARK: - Cover Letter

struct CoverLetterTabView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let app = viewModel.selectedApplication {
                OutputSection(label: "Customized For") {
                    Text("\(app.company) · \(app.role)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.accentText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accentBg))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.accentBorder, lineWidth: 1))
                }
            }

            if let raw = viewModel.selectedGeneratedContent?.coverLetter {
                let parts = CoverLetterParts.parse(raw)
                OutputSection(label: "Cover Letter") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Dear Hiring Team,")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.text1)

                        if let parts {
                            HighlightedBlock(text: parts.firstParagraph.plainLanguage)
                            HighlightedBlock(text: parts.companySentence.plainLanguage)
                        } else {
                            Text(raw.plainLanguage)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Theme.text1)
                                .lineSpacing(5)
                        }

                        Text("I'd welcome the chance to talk further.\n\nSincerely,\n[Your Name]")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.text1)
                    }
                }
                CopyRow(title: "⧉ Copy Letter", text: fullLetterText(raw: raw, parts: parts))
            } else {
                EmptyContentNote(text: "No cover letter generated yet.")
            }
        }
    }

    private func fullLetterText(raw: String, parts: CoverLetterParts?) -> String {
        let body = parts.map { "\($0.firstParagraph)\n\n\($0.companySentence)" } ?? raw
        return "Dear Hiring Team,\n\n\(body)\n\nI'd welcome the chance to talk further.\n\nSincerely,\n[Your Name]".plainLanguage
    }
}

// MARK: - Outreach

struct OutreachTabView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        Group {
            if let content = viewModel.selectedGeneratedContent {
                OutreachEditor(content: content)
                    .id(viewModel.selectedApplicationID)
            } else {
                EmptyContentNote(text: "No outreach message generated yet.")
            }
        }
    }
}

private struct OutreachEditor: View {
    let content: GeneratedContent
    @State private var subject: String
    @State private var message: String

    init(content: GeneratedContent) {
        self.content = content
        _subject = State(initialValue: content.outreachSubject)
        _message = State(initialValue: content.outreach)
    }

    var body: some View {
        VStack(spacing: 0) {
            OutputSection(label: "Subject Line") {
                TextField("", text: $subject)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.borderStrong, lineWidth: 1))
            }

            OutputSection(label: "Message") {
                TextEditor(text: $message)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.text1)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 160)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.borderStrong, lineWidth: 1))
            }

            CopyRow(title: "⧉ Copy Message", text: "\(subject)\n\n\(message)".plainLanguage)
        }
    }
}

// MARK: - Tracker

struct TrackerTabView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        if let app = viewModel.selectedApplication {
            TrackerForm(application: app, viewModel: viewModel)
                .id(app.id)
        } else {
            EmptyContentNote(text: "Select or generate an application to log it.")
        }
    }
}

private struct TrackerForm: View {
    @Bindable var application: Application
    let viewModel: AppViewModel

    @State private var hasFollowUp: Bool
    @State private var followUpDate: Date

    init(application: Application, viewModel: AppViewModel) {
        self.application = application
        self.viewModel = viewModel
        _hasFollowUp = State(initialValue: application.followUpDate != nil)
        _followUpDate = State(initialValue: application.followUpDate ?? .now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LOG THIS APPLICATION")
                .font(Theme.Font.label())
                .foregroundStyle(Theme.text3)
                .tracking(0.8)

            field("Company", text: $application.company)
            field("Role", text: $application.role)
            salaryField
            field("Apply Link", text: $application.applyLink)

            VStack(alignment: .leading, spacing: 4) {
                Text("STATUS").font(Theme.Font.label(11)).foregroundStyle(Theme.text3).tracking(0.5)
                Picker("", selection: $application.status) {
                    ForEach(ApplicationStatus.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Follow-up date", isOn: $hasFollowUp.animation())
                    .font(Theme.Font.label(11))
                    .foregroundStyle(Theme.text3)
                if hasFollowUp {
                    DatePicker("", selection: $followUpDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.field)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("NOTES").font(Theme.Font.label(11)).foregroundStyle(Theme.text3).tracking(0.5)
                TextField("e.g. contacted Sarah Chen on LinkedIn", text: $application.notes)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.borderStrong, lineWidth: 1))
            }

            if let trackerNote = viewModel.selectedGeneratedContent?.trackerNote {
                Text(trackerNote.plainLanguage)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.text3)
            }

            Button("Save Application") {
                application.followUpDate = hasFollowUp ? followUpDate : nil
                viewModel.saveEdits(to: application)
            }
            .buttonStyle(PursuitButtonStyle(kind: .primary))
            .font(.system(size: 13, weight: .medium))
        }
        .padding(16)
    }

    @ViewBuilder
    private var salaryField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SALARY").font(Theme.Font.label(11)).foregroundStyle(Theme.text3).tracking(0.5)
            if application.salaryMissing {
                HStack(spacing: 4) {
                    Text("⚑")
                    Text("Not listed")
                }
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.amber)
                .padding(.horizontal, 10)
                .frame(height: 30, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.borderStrong, lineWidth: 1))
            } else {
                field("", text: Binding(
                    get: { application.salary ?? "" },
                    set: { application.salary = $0.isEmpty ? nil : $0 }
                ))
            }
        }
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !label.isEmpty {
                Text(label.uppercased()).font(Theme.Font.label(11)).foregroundStyle(Theme.text3).tracking(0.5)
            }
            TextField("", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.borderStrong, lineWidth: 1))
        }
    }
}

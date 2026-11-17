import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.templateLoader.isConfigured {
                TemplateSetupBanner()
            }

            NavigationSplitView {
                SidebarView()
                    .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
            } content: {
                CenterPaneView()
                    .navigationSplitViewColumnWidth(min: 420, ideal: 540)
            } detail: {
                DetailPaneView()
                    .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 440)
            }
            .navigationSplitViewStyle(.balanced)
            .toolbar { toolbarContent }

            StatusBarView()
        }
        .task {
            let hasPrompted = UserDefaults.standard.bool(forKey: "HasPromptedForTemplateFolder")
            if !hasPrompted && !viewModel.templateLoader.isConfigured {
                UserDefaults.standard.set(true, forKey: "HasPromptedForTemplateFolder")
                viewModel.templateLoader.promptForFolderAndImport()
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                viewModel.reset()
            } label: {
                Label("New Application", systemImage: "plus")
            }
        }
        ToolbarItem {
            Button {
                viewModel.acceptDrop(text: DemoContent.jdText)
            } label: {
                Label("Import JD", systemImage: "square.and.arrow.down")
            }
        }
        ToolbarItem {
            TextField("Search applications…", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 10)
                .frame(width: 200, height: 26)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.borderStrong, lineWidth: 1))
        }
        ToolbarItem {
            ModelStatusPill()
        }
    }
}

private struct TemplateSetupBanner: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.badge.questionmark")
                .foregroundStyle(Theme.amber)
            Text("No resume or templates on file yet. Pursuit will still generate content, but it won't match your voice.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.text2)
            Spacer()
            Button("Locate Toolkit Folder…") {
                viewModel.templateLoader.promptForFolderAndImport()
            }
            .buttonStyle(PursuitButtonStyle(kind: .secondary))
            .font(.system(size: 11.5, weight: .medium))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Theme.amber.opacity(0.1))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }
}

private struct ModelStatusPill: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(dotColor).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.text2)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(Capsule().fill(Theme.surface))
        .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
    }

    private var label: String {
        let manager = viewModel.modelManager
        if manager.activeSource == .claudeAPI && manager.claudeReachable { return "Claude API" }
        if manager.activeSource == .ollama && manager.ollamaReachable { return "Local Model" }
        return "Offline"
    }

    private var dotColor: Color {
        let manager = viewModel.modelManager
        if manager.activeSource == .claudeAPI && manager.claudeReachable { return Theme.green }
        if manager.activeSource == .ollama && manager.ollamaReachable { return Theme.amber }
        return Theme.red
    }
}

struct StatusBarView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Circle().fill(statusColor).frame(width: 6, height: 6)
                Text(statusText)
                    .foregroundStyle(statusColor)
            }
            Text("\(viewModel.appliedCount) of \(viewModel.applications.count) applications submitted")
                .foregroundStyle(Theme.text3)
            Spacer()
        }
        .font(.system(size: 10.5))
        .padding(.horizontal, 14)
        .frame(height: 24)
        .background(Theme.sidebar)
        .overlay(alignment: .top) { Rectangle().fill(Theme.border).frame(height: 1) }
    }

    private var statusText: String {
        let manager = viewModel.modelManager
        if manager.activeSource == .claudeAPI && manager.claudeReachable { return "Claude API connected" }
        if manager.activeSource == .ollama && manager.ollamaReachable { return "Local ollama fallback active" }
        return "No model backend reachable"
    }

    private var statusColor: Color {
        let manager = viewModel.modelManager
        if manager.activeSource == .claudeAPI && manager.claudeReachable { return Theme.green }
        if manager.activeSource == .ollama && manager.ollamaReachable { return Theme.amber }
        return Theme.red
    }
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel.preview)
        .frame(width: 1160, height: 740)
}

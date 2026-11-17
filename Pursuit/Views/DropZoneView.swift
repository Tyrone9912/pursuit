import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 12) {
            Text("📄")
                .font(.system(size: 36))
                .opacity(0.35)

            Text("Drop a job description here")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text1)

            Text("Paste the full JD text, drop a PDF, or import a URL. Pursuit extracts the role, company, and requirements automatically.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.text3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
                .lineSpacing(3)

            HStack(spacing: 8) {
                Button {
                    pasteFromClipboard()
                } label: {
                    Text("Paste Text")
                }
                .buttonStyle(PursuitButtonStyle(kind: .secondary))

                Button {
                    viewModel.acceptDrop(text: DemoContent.jdText)
                } label: {
                    Text("▶ Try Demo Flow")
                }
                .buttonStyle(PursuitButtonStyle(kind: .demo))
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .strokeBorder(
                    viewModel.isDropTargeted ? Theme.accent : Theme.borderStrong,
                    style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                )
        )
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(viewModel.isDropTargeted ? Theme.accentBg : Color.clear)
        )
        .padding(EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18))
        .animation(.easeOut(duration: 0.15), value: viewModel.isDropTargeted)
        .onDrop(of: [.fileURL, .plainText], isTargeted: $viewModel.isDropTargeted) { providers in
            handleDrop(providers)
        }
    }

    private func pasteFromClipboard() {
        if let text = NSPasteboard.general.string(forType: .string), !text.isEmpty {
            viewModel.acceptDrop(text: text)
        } else {
            viewModel.acceptDrop(text: DemoContent.jdText)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      let text = try? String(contentsOf: url, encoding: .utf8) else { return }
                DispatchQueue.main.async {
                    viewModel.acceptDrop(text: text)
                }
            }
            return true
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, _ in
                let text: String?
                if let data = item as? Data {
                    text = String(data: data, encoding: .utf8)
                } else {
                    text = item as? String
                }
                guard let text, !text.isEmpty else { return }
                DispatchQueue.main.async {
                    viewModel.acceptDrop(text: text)
                }
            }
            return true
        }

        return false
    }
}

enum PursuitButtonKind {
    case primary, secondary, demo
}

struct PursuitButtonStyle: ButtonStyle {
    var kind: PursuitButtonKind = .secondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .medium))
            .padding(.horizontal, 14)
            .frame(height: 30)
            .foregroundStyle(foreground)
            .background(background(pressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .strokeBorder(borderColor, lineWidth: kind == .secondary ? 1 : 0)
            )
    }

    private var foreground: Color {
        switch kind {
        case .primary, .demo: return .white
        case .secondary: return Theme.text1
        }
    }

    private var borderColor: Color {
        kind == .secondary ? Theme.borderStrong : .clear
    }

    private func background(pressed: Bool) -> Color {
        switch kind {
        case .primary, .demo: return pressed ? Theme.accentMid : Theme.accent
        case .secondary: return pressed ? Theme.surface : Theme.surface2
        }
    }
}

#Preview {
    DropZoneView()
        .environmentObject(AppViewModel.preview)
        .frame(width: 500, height: 400)
        .background(Theme.background)
}

import SwiftUI

struct CenterPaneView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(paneLabel)
                    .font(Theme.Font.label())
                    .foregroundStyle(Theme.text3)
                    .tracking(0.9)
                Spacer()
                if viewModel.centerState != .empty {
                    Button("Start Over") { viewModel.reset() }
                        .buttonStyle(.link)
                        .font(.system(size: 11.5))
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, viewModel.centerState == .empty ? 0 : 6)

            switch viewModel.centerState {
            case .empty:
                DropZoneView()
            case .processing, .result:
                JDResultView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    private var paneLabel: String {
        viewModel.centerState == .empty ? "Drop Zone" : "Job Description"
    }
}

#Preview {
    CenterPaneView()
        .environmentObject(AppViewModel.preview)
        .frame(width: 560, height: 700)
}

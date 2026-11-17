import SwiftUI

enum DetailTab: String, CaseIterable, Identifiable {
    case research = "Research"
    case coverLetter = "Cover Letter"
    case outreach = "Outreach"
    case tracker = "Tracker"

    var id: String { rawValue }
}

struct DetailPaneView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var activeTab: DetailTab = .research

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.centerState == .result {
                tabBar
                tabContent
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .animation(.easeOut(duration: 0.25), value: viewModel.centerState)
    }

    private var placeholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("OUTPUTS")
                .font(Theme.Font.label())
                .foregroundStyle(Theme.text3)
                .tracking(0.9)

            VStack(alignment: .leading, spacing: 8) {
                placeholderRow(1, "Customized cover letter first paragraph")
                placeholderRow(2, "Tailored sentence specific to this company")
                placeholderRow(3, "Cold outreach message with contact identified")
                placeholderRow(4, "Company research + conversation angles")
                placeholderRow(5, "Application logged to tracker")
            }
            .opacity(0.55)
            .padding(.top, 4)

            Spacer()

            Text("Drop a job description to generate\nyour personalized application materials.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.text3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(EdgeInsets(top: 40, leading: 24, bottom: 24, trailing: 24))
    }

    private func placeholderRow(_ number: Int, _ text: String) -> some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.text3)
                .frame(width: 20, height: 20)
                .overlay(Circle().strokeBorder(Theme.borderStrong, lineWidth: 1))
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Theme.text3)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(DetailTab.allCases) { tab in
                Button {
                    activeTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(activeTab == tab ? Theme.accent : Theme.text3)
                        .padding(.horizontal, 10)
                        .padding(.top, 4)
                        .padding(.bottom, 7)
                        .background(activeTab == tab ? Theme.tabActiveBg : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(activeTab == tab ? Theme.accent : Color.clear)
                                .frame(height: 2)
                        }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .background(Theme.toolbar)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        ScrollView {
            switch activeTab {
            case .coverLetter: CoverLetterTabView()
            case .outreach: OutreachTabView()
            case .research: ResearchTabView()
            case .tracker: TrackerTabView()
            }
        }
    }
}

#Preview {
    let vm = AppViewModel.preview
    vm.centerState = .result
    return DetailPaneView()
        .environmentObject(vm)
        .frame(width: 380, height: 700)
}

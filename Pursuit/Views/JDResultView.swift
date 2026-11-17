import SwiftUI

struct JDResultView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.border)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    processingLog

                    if let error = viewModel.pipelineError {
                        HStack(alignment: .top, spacing: 6) {
                            Text("⚠").foregroundStyle(Theme.amber)
                            Text(error).foregroundStyle(Theme.amber)
                        }
                        .font(.system(size: 12))
                        .padding(.horizontal, 18)
                    }

                    Divider().overlay(Theme.border)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("ORIGINAL JD")
                            .font(Theme.Font.label())
                            .foregroundStyle(Theme.text3)
                            .tracking(0.8)
                        Text(viewModel.droppedText)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.text2)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(viewModel.selectedApplication?.company ?? "Parsing…")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.text1)
            Text(viewModel.selectedApplication?.role ?? "")
                .font(.system(size: 13))
                .foregroundStyle(Theme.text2)

            salaryBadge
                .padding(.top, 6)
        }
        .padding(EdgeInsets(top: 12, leading: 18, bottom: 10, trailing: 18))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
    }

    @ViewBuilder
    private var salaryBadge: some View {
        if let app = viewModel.selectedApplication {
            if let salary = app.salary {
                Text(salary)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.accentText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.accentBg))
                    .overlay(Capsule().strokeBorder(Theme.accentBorder, lineWidth: 1))
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "flag.fill").font(.system(size: 9))
                    Text("No salary listed")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.amber)
                .padding(.horizontal, 10)
                .padding(.vertical, 2)
                .background(Capsule().fill(Theme.amber.opacity(0.12)))
                .overlay(Capsule().strokeBorder(Theme.amber.opacity(0.3), lineWidth: 1))
            }
        }
    }

    private var processingLog: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PROCESSING LOG")
                .font(Theme.Font.label())
                .foregroundStyle(Theme.text3)
                .tracking(0.8)

            ForEach(viewModel.processingSteps) { step in
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(iconBackground(step))
                            .overlay(Circle().strokeBorder(iconBorder(step), lineWidth: 1))
                        if step.isDone {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Theme.accentText)
                        } else if step.isFailed {
                            Image(systemName: "exclamationmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Theme.amber)
                        } else if step.isVisible {
                            ProgressView()
                                .controlSize(.mini)
                        }
                    }
                    .frame(width: 22, height: 22)

                    (Text(step.label + ": ").fontWeight(.semibold).foregroundStyle(Theme.text1)
                        + Text(step.detail).foregroundStyle(Theme.text2))
                        .font(.system(size: 12.5))
                }
                .opacity(step.isVisible ? 1 : 0)
                .offset(x: step.isVisible ? 0 : -6)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }

    private func iconBackground(_ step: ProcessingStep) -> Color {
        if step.isDone { return Theme.accentBg }
        if step.isFailed { return Theme.amber.opacity(0.12) }
        return Theme.surface2
    }

    private func iconBorder(_ step: ProcessingStep) -> Color {
        if step.isDone { return Theme.accentBorder }
        if step.isFailed { return Theme.amber.opacity(0.3) }
        return Theme.border
    }
}

#Preview {
    let vm = AppViewModel.preview
    JDResultView()
        .environmentObject(vm)
        .frame(width: 560, height: 700)
        .background(Theme.background)
        .onAppear { vm.acceptDrop(text: DemoContent.jdText) }
}

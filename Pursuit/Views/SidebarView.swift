import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    private var inProgress: [Application] {
        viewModel.filteredApplications.filter { $0.status == .preparing }
    }

    private var applied: [Application] {
        viewModel.filteredApplications.filter { $0.status != .preparing }
    }

    var body: some View {
        VStack(spacing: 0) {
            ProfileSwitcher()

            Divider().overlay(Theme.border)

            statsRow

            Divider().overlay(Theme.border)

            if viewModel.applications.isEmpty {
                Text("No applications yet.\nDrop a job description to get started.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.text3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if !inProgress.isEmpty {
                            sectionHeader("In Progress")
                            ForEach(inProgress) { app in rowButton(app) }
                        }

                        if !applied.isEmpty {
                            sectionHeader("Applied")
                            ForEach(applied) { app in rowButton(app) }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .background(Theme.sidebar)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(Theme.text3)
            .tracking(0.6)
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rowButton(_ app: Application) -> some View {
        SidebarRow(application: app, isSelected: viewModel.selectedApplicationID == app.id)
            .contentShape(Rectangle())
            .onTapGesture { viewModel.selectApplication(app) }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatBlock(number: viewModel.appliedCount, label: "Applied")
            Divider().frame(height: 26).overlay(Theme.border)
            StatBlock(number: viewModel.remainingCount, label: "Remaining")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct ProfileSwitcher: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var isAddingProfile = false
    @State private var isRenamingProfile = false
    @State private var draftName = ""

    var body: some View {
        Menu {
            ForEach(viewModel.profiles, id: \.id) { profile in
                Button {
                    viewModel.switchProfile(profile)
                } label: {
                    if profile.id == viewModel.currentProfileID {
                        Label(profile.name, systemImage: "checkmark")
                    } else {
                        Text(profile.name)
                    }
                }
            }

            Divider()

            Button("Add Profile…") {
                draftName = ""
                isAddingProfile = true
            }

            if let current = viewModel.currentProfile {
                Button("Rename “\(current.name)”…") {
                    draftName = current.name
                    isRenamingProfile = true
                }
                if viewModel.profiles.count > 1 {
                    Button("Delete “\(current.name)”", role: .destructive) {
                        viewModel.deleteProfile(current)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle")
                    .foregroundStyle(Theme.text2)
                Text(viewModel.currentProfile?.name ?? "Profile")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.text1)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.text3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .alert("New Profile", isPresented: $isAddingProfile) {
            TextField("Name", text: $draftName)
            Button("Add") { viewModel.addProfile(name: draftName) }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename Profile", isPresented: $isRenamingProfile) {
            TextField("Name", text: $draftName)
            Button("Save") {
                if let current = viewModel.currentProfile {
                    viewModel.renameProfile(current, to: draftName)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct StatBlock: View {
    let number: Int
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(number)")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.text1)
                .monospacedDigit()
            Text(label.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.text3)
                .tracking(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SidebarRow: View {
    let application: Application
    let isSelected: Bool
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(application.company)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.text1)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Circle()
                    .fill(application.status.dotColor)
                    .frame(width: 7, height: 7)
            }
            Text(application.role)
                .font(.system(size: 11))
                .foregroundStyle(Theme.text2)
                .lineLimit(1)
            salaryRow
            Text(dateText)
                .font(.system(size: 10))
                .foregroundStyle(Theme.text3)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
        .overlay(alignment: .leading) {
            if isSelected {
                Rectangle().fill(Theme.accent).frame(width: 2)
            }
        }
        .onHover { isHovering = $0 }
    }

    private var rowBackground: Color {
        if isSelected { return Theme.accentBg }
        if isHovering { return Color.gray.opacity(0.07) }
        return .clear
    }

    @ViewBuilder
    private var salaryRow: some View {
        if let salary = application.salary {
            Text(salary)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Theme.accentText)
                .lineLimit(1)
        } else {
            HStack(spacing: 3) {
                Text("⚑")
                Text("Salary not listed")
            }
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(Theme.amber)
        }
    }

    private var dateText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let relative = formatter.localizedString(for: application.dateAdded, relativeTo: .now)
        if let detail = application.statusDetail {
            return "\(relative) · \(detail)"
        }
        return relative
    }
}

#Preview {
    SidebarView()
        .environmentObject(AppViewModel.preview)
        .frame(width: 220, height: 600)
}

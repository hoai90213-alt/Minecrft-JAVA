import SwiftUI

struct ProfilesView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Game Profiles")
                    .font(.headline)
                Spacer()
                Button {
                    let profile = GameProfile(name: "New Profile", version: "1.21.4")
                    container.profiles.append(profile)
                    container.selectedProfileID = profile.id
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .glassCard(cornerRadius: 10, intensity: container.dashboardGlassIntensity)
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(container.profiles) { profile in
                        profileRow(profile)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .padding(14)
        .glassCard(intensity: container.dashboardGlassIntensity)
    }

    private func profileRow(_ profile: GameProfile) -> some View {
        Button {
            container.selectedProfileID = profile.id
        } label: {
            HStack {
                Image(systemName: profile.id == container.selectedProfileID ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(GlassTheme.actionTint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.subheadline.weight(.semibold))
                    Text("Version \(profile.version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .glassCard(cornerRadius: 10, intensity: container.dashboardGlassIntensity)
    }
}

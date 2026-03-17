import SwiftUI

struct HomeDashboardView: View {
    @EnvironmentObject private var container: AppContainer

    private let columns = [
        GridItem(.adaptive(minimum: 230), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                statusCard
                quickActionCard
                accountCard
                installCard
            }
            .padding(.bottom, 12)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Runtime Status")
                .font(.headline)
            Text(container.statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Divider().overlay(Color.white.opacity(0.15))
            HStack {
                Label("Profile", systemImage: "square.stack.3d.up")
                    .font(.caption)
                Spacer()
                Text(container.selectedProfile?.name ?? "None")
                    .font(.caption.weight(.semibold))
            }
            HStack {
                Label("Account", systemImage: "person.circle")
                    .font(.caption)
                Spacer()
                Text(container.selectedAccount?.username ?? "None")
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(14)
        .glassCard(intensity: container.dashboardGlassIntensity)
    }

    private var quickActionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Actions")
                .font(.headline)
            HStack(spacing: 8) {
                actionTile(title: "Play", icon: "play.fill") {
                    Task { await container.launchSelectedProfile() }
                }
                actionTile(title: "Profiles", icon: "slider.horizontal.3") {
                    container.section = .profiles
                }
                actionTile(title: "Install", icon: "square.and.arrow.down.fill") {
                    container.section = .installer
                }
            }
        }
        .padding(14)
        .glassCard(intensity: container.dashboardGlassIntensity)
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Account State")
                .font(.headline)
            ForEach(container.accounts) { account in
                HStack {
                    Image(systemName: account.id == container.selectedAccountID ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(GlassTheme.actionTint)
                    Text(account.username)
                    Spacer()
                    Text(account.provider)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
        .padding(14)
        .glassCard(intensity: container.dashboardGlassIntensity)
    }

    private var installCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Installer State")
                .font(.headline)
            HStack {
                Text("Source")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(container.installerSource.title)
                    .font(.subheadline.weight(.semibold))
            }
            HStack {
                Text("Query")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(container.installerQuery.isEmpty ? "-" : container.installerQuery)
                    .lineLimit(1)
            }
            HStack {
                Text("Results")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(container.installerResults.count)")
            }
        }
        .padding(14)
        .glassCard(intensity: container.dashboardGlassIntensity)
    }

    private func actionTile(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.headline)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 70)
        }
        .buttonStyle(.plain)
        .glassCard(cornerRadius: 12, intensity: container.dashboardGlassIntensity)
    }
}

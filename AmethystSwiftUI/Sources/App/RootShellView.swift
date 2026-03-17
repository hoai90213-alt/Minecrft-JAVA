import SwiftUI

struct RootShellView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        ZStack {
            DashboardBackgroundView(
                mode: container.dashboardBackgroundMode,
                imagePath: container.dashboardBackgroundPath,
                blurStrength: container.dashboardBlurStrength
            )

            NavigationSplitView {
                SidebarMenuView(selection: $container.section, glassIntensity: container.dashboardGlassIntensity)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 8)
            } detail: {
                VStack(spacing: 12) {
                    DetailHeaderView()
                    DetailContentView(section: container.section)
                }
                .padding(12)
            }
            .navigationSplitViewStyle(.balanced)
        }
    }
}

private struct DetailHeaderView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        HStack(spacing: 10) {
            Text(container.section.title)
                .font(.title2.weight(.semibold))
            Spacer()
            if container.isBusy {
                ProgressView()
                    .tint(GlassTheme.actionTint)
            }
            Button {
                Task { await container.launchSelectedProfile() }
            } label: {
                Label("Play", systemImage: "play.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .glassCard(cornerRadius: 12, intensity: container.dashboardGlassIntensity)
        }
        .padding(12)
        .glassCard(cornerRadius: 16, intensity: container.dashboardGlassIntensity)
    }
}

private struct SidebarMenuView: View {
    @Binding var selection: AppSection
    let glassIntensity: Double

    var body: some View {
        VStack(spacing: 8) {
            ForEach(AppSection.allCases) { section in
                Button {
                    selection = section
                } label: {
                    Image(systemName: section.iconName)
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(4)
                .background(selection == section ? GlassTheme.selectedFill : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel(section.title)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(minWidth: 68, maxWidth: 84)
        .glassCard(cornerRadius: 18, intensity: glassIntensity)
    }
}

private struct DetailContentView: View {
    let section: AppSection

    var body: some View {
        switch section {
        case .home:
            HomeDashboardView()
        case .profiles:
            ProfilesView()
        case .installer:
            InstallerView()
        case .accounts:
            AccountsView()
        case .settings:
            SettingsView()
        }
    }
}

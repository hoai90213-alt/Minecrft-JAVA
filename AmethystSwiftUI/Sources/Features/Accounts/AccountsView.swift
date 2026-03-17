import SwiftUI

struct AccountsView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Accounts")
                    .font(.headline)
                Spacer()
                Button {
                    let account = LauncherAccount(
                        username: "Demo\(container.accounts.count + 1)",
                        provider: "Local"
                    )
                    container.accounts.append(account)
                    container.selectedAccountID = account.id
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
                    ForEach(container.accounts) { account in
                        Button {
                            container.selectedAccountID = account.id
                        } label: {
                            HStack {
                                Image(systemName: account.id == container.selectedAccountID ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(GlassTheme.actionTint)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(account.username)
                                        .font(.subheadline.weight(.semibold))
                                    Text(account.provider)
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
                .padding(.bottom, 8)
            }
        }
        .padding(14)
        .glassCard(intensity: container.dashboardGlassIntensity)
    }
}

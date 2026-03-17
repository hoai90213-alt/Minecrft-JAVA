import SwiftUI

struct InstallerView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Modpack Installer")
                .font(.headline)

            Picker("Source", selection: $container.installerSource) {
                ForEach(InstallerSource.allCases) { source in
                    Text(source.title).tag(source)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                TextField("Search modpacks or loaders", text: $container.installerQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(10)
                    .glassCard(cornerRadius: 10, intensity: container.dashboardGlassIntensity)

                Button {
                    Task { await container.searchInstaller() }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassCard(cornerRadius: 10, intensity: container.dashboardGlassIntensity)
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(container.installerResults) { result in
                        HStack(alignment: .top) {
                            Image(systemName: "shippingbox.fill")
                                .foregroundStyle(GlassTheme.actionTint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(result.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
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

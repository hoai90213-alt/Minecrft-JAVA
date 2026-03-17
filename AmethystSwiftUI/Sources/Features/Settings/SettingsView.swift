import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var container: AppContainer

    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showFileImporter = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Dashboard Settings")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Background")
                        .font(.subheadline.weight(.semibold))

                    Picker("Background Mode", selection: $container.dashboardBackgroundMode) {
                        ForEach(DashboardBackgroundMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 8) {
                        PhotosPicker(selection: $photoPickerItem, matching: .images) {
                            Label("Photos", systemImage: "photo")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 10)
                        .glassCard(cornerRadius: 10, intensity: container.dashboardGlassIntensity)

                        Button {
                            showFileImporter = true
                        } label: {
                            Label("Files", systemImage: "folder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 10)
                        .glassCard(cornerRadius: 10, intensity: container.dashboardGlassIntensity)
                    }

                    Button(role: .destructive) {
                        container.resetBackground()
                    } label: {
                        Label("Reset Background", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 10)
                    .glassCard(cornerRadius: 10, intensity: container.dashboardGlassIntensity)
                }
                .padding(12)
                .glassCard(cornerRadius: 14, intensity: container.dashboardGlassIntensity)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Blur Strength")
                        Spacer()
                        Text(String(format: "%.2f", container.dashboardBlurStrength))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $container.dashboardBlurStrength, in: 0...1)

                    HStack {
                        Text("Glass Intensity")
                        Spacer()
                        Text(String(format: "%.2f", container.dashboardGlassIntensity))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $container.dashboardGlassIntensity, in: 0.2...1)
                }
                .padding(12)
                .glassCard(cornerRadius: 14, intensity: container.dashboardGlassIntensity)
            }
            .padding(14)
        }
        .glassCard(intensity: container.dashboardGlassIntensity)
        .onChange(of: photoPickerItem) { newValue in
            guard let newValue else { return }
            Task {
                do {
                    if let data = try await newValue.loadTransferable(type: Data.self) {
                        try container.importBackground(data: data, fileName: "picked_photo.jpg", from: .photos)
                        container.statusText = "Background imported from Photos"
                    }
                } catch {
                    container.statusText = error.localizedDescription
                }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [UTType.image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let granted = url.startAccessingSecurityScopedResource()
                defer {
                    if granted {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                do {
                    let data = try Data(contentsOf: url)
                    try container.importBackground(data: data, fileName: url.lastPathComponent, from: .files)
                    container.statusText = "Background imported from Files"
                } catch {
                    container.statusText = error.localizedDescription
                }
            case .failure(let error):
                container.statusText = error.localizedDescription
            }
        }
    }
}

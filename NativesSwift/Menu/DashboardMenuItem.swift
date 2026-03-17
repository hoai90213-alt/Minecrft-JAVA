import Foundation

struct DashboardMenuItem: Hashable {
    let id: String
    let title: String
    let symbolName: String

    static let defaults: [DashboardMenuItem] = [
        .init(id: "news", title: "News", symbolName: "newspaper"),
        .init(id: "profiles", title: "Profiles", symbolName: "person.crop.square"),
        .init(id: "settings", title: "Settings", symbolName: "slider.horizontal.3"),
        .init(id: "controls", title: "Controls", symbolName: "gamecontroller"),
        .init(id: "jar", title: "Execute Jar", symbolName: "triangle.circle.square"),
        .init(id: "logs", title: "Send Logs", symbolName: "square.and.arrow.up")
    ]
}

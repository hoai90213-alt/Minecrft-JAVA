import UIKit

@objcMembers
final class SwiftMenuFactory: NSObject {
    static func makeMenuController(
        items: [DashboardMenuItem] = .defaults,
        onSelect: ((DashboardMenuItem) -> Void)? = nil
    ) -> UIViewController {
        let controller = SwiftLauncherMenuViewController()
        controller.items = items
        controller.onSelectItem = onSelect
        return controller
    }
}

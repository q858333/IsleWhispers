import UIKit

nonisolated final class AppLaunchCoordinator {
    private let window: UIWindow
    private let agreementDefaults: UserDefaults
    private let links: AppSupportLinks
    private let scheduleRoute: LaunchViewController.RouteScheduler
    private let makeRootViewController: @MainActor () -> UIViewController
    private var didShowRootViewController = false

    @MainActor
    init(
        window: UIWindow,
        agreementDefaults: UserDefaults = .standard,
        links: AppSupportLinks? = nil,
        scheduleRoute: @escaping LaunchViewController.RouteScheduler = LaunchViewController.scheduleRoute,
        makeRootViewController: @escaping @MainActor () -> UIViewController = {
            RootTabBarController(playerService: .shared, recentStore: RecentSoundsStore())
        }
    ) {
        self.window = window
        self.agreementDefaults = agreementDefaults
        self.links = links ?? .current
        self.scheduleRoute = scheduleRoute
        self.makeRootViewController = makeRootViewController
    }

    @MainActor
    func start() {
        let launchViewController = LaunchViewController(
            agreementDefaults: agreementDefaults,
            links: links,
            scheduleRoute: scheduleRoute,
            onContinue: { [weak self] in
                self?.showRootViewControllerIfNeeded()
            }
        )
        window.rootViewController = launchViewController
        window.makeKeyAndVisible()
    }

    @MainActor
    private func showRootViewControllerIfNeeded() {
        guard !didShowRootViewController else { return }
        didShowRootViewController = true
        window.rootViewController = makeRootViewController()
    }
}

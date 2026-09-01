import UIKit

final class RootTabBarController: UITabBarController {
    let homeViewController: HomeViewController
    let soundLibraryViewController: SoundLibraryViewController
    let settingsViewController: SettingsViewController
    private let playerService: AudioPlayerService
    private let recentStore: RecentSoundsStore

    override var selectedIndex: Int {
        didSet {
            updateTabBarAppearance(for: selectedIndex)
        }
    }

    override var selectedViewController: UIViewController? {
        didSet {
            updateTabBarAppearance(for: selectedIndex)
        }
    }

    init(playerService: AudioPlayerService, recentStore: RecentSoundsStore) {
        self.playerService = playerService
        self.recentStore = recentStore
        homeViewController = HomeViewController(
            playerService: playerService,
            recentStore: recentStore
        )
        soundLibraryViewController = SoundLibraryViewController(
            selectedSoundID: playerService.currentSound.id
        )
        settingsViewController = SettingsViewController()
        super.init(nibName: nil, bundle: nil)

        homeViewController.tabBarItem = UITabBarItem(
            title: "首页",
            image: UIImage(systemName: "house.fill"),
            selectedImage: UIImage(systemName: "house.fill")
        )
        soundLibraryViewController.tabBarItem = UITabBarItem(
            title: "声音",
            image: UIImage(systemName: "square.grid.2x2.fill"),
            selectedImage: UIImage(systemName: "square.grid.2x2.fill")
        )
        let settingsNavigationController = UINavigationController(
            rootViewController: settingsViewController
        )
        settingsNavigationController.tabBarItem = UITabBarItem(
            title: "设置",
            image: UIImage(systemName: "gearshape.fill"),
            selectedImage: UIImage(systemName: "gearshape.fill")
        )
        viewControllers = [
            homeViewController,
            soundLibraryViewController,
            settingsNavigationController
        ]

        soundLibraryViewController.onSelect = { [weak self] index in
            self?.selectSoundFromLibrary(at: index)
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlayerStateDidChange),
            name: .audioPlayerStateDidChange,
            object: playerService
        )
        updateTabBarAppearance(for: selectedIndex)
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func selectSoundFromLibrary(at index: Int) {
        homeViewController.selectAndPlaySound(at: index, animated: false)
        soundLibraryViewController.updateSelectedSound(id: Sound.catalog[index].id)
        selectedIndex = 0
    }

    @objc private func handlePlayerStateDidChange() {
        soundLibraryViewController.updateSelectedSound(id: playerService.currentSound.id)
    }

    private func updateTabBarAppearance(for index: Int) {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        if index == 0 {
            appearance.backgroundColor = AppTheme.tabBarBackground
            appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
            appearance.stackedLayoutAppearance.selected.iconColor = .white
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor.white
            ]
        } else {
            let selectedColor = AppTheme.secondaryTabBarForeground
            let normalColor = selectedColor.withAlphaComponent(0.58)
            appearance.backgroundColor = AppTheme.secondaryTabBarBackground
            appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
            appearance.shadowColor = AppTheme.warmRose.withAlphaComponent(0.18)
            appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: selectedColor
            ]
            appearance.stackedLayoutAppearance.normal.iconColor = normalColor
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: normalColor
            ]
        }

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.isTranslucent = true
    }
}

import Defaults
import MediaPlayer
import PINCache
import SDWebImage
import SDWebImageWebPCoder
import Siesta
import SwiftUI

@main
struct YatteeApp: App {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
    }

    static var isForPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    static var logsDirectory: URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }

    #if os(macOS)
        @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #elseif os(iOS)
        @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    @State private var configured = false

    @StateObject private var accounts = AccountsModel.shared
    @StateObject private var comments = CommentsModel.shared
    @StateObject private var instances = InstancesModel.shared
    @StateObject private var menu = MenuModel.shared
    @StateObject private var navigation = NavigationModel.shared
    @StateObject private var networkState = NetworkStateModel.shared
    @StateObject private var player = PlayerModel.shared
    @StateObject private var playlists = PlaylistsModel.shared
    @StateObject private var recents = RecentsModel.shared
    @StateObject private var settings = SettingsModel.shared
    @StateObject private var subscriptions = SubscribedChannelsModel.shared
    @StateObject private var thumbnails = ThumbnailsModel.shared

    let persistenceController = PersistenceController.shared

    var favorites: FavoritesModel { .shared }
    var playerControls: PlayerControlsModel { .shared }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear(perform: configure)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
            #if os(macOS)
                .background(
                    HostingWindowFinder { window in
                        Windows.mainWindow = window
                    }
                )
            #else
                .onReceive(
                        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
                    ) { _ in
                        player.handleEnterForeground()
                    }
                    .onReceive(
                        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
                    ) { _ in
                        player.handleEnterBackground()
                    }
            #endif
            #if os(iOS)
            .handlesExternalEvents(preferring: Set(["*"]), allowing: Set(["*"]))
            #endif
        }
        #if os(iOS)
        .handlesExternalEvents(matching: Set(["*"]))
        #endif
        #if !os(tvOS)
        .commands {
            SidebarCommands()

            CommandGroup(replacing: .newItem, addition: {})

            MenuCommands(model: Binding<MenuModel>(get: { MenuModel.shared }, set: { _ in }))
        }
        #endif

        #if os(macOS)
            WindowGroup(player.windowTitle) {
                VideoPlayerView()
                    .onAppear(perform: configure)
                    .background(
                        HostingWindowFinder { window in
                            Windows.playerWindow = window

                            NotificationCenter.default.addObserver(
                                forName: NSWindow.willExitFullScreenNotification,
                                object: window,
                                queue: OperationQueue.main
                            ) { _ in
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    self.player.playingFullScreen = false
                                }
                            }
                        }
                    )
                    .onAppear { player.presentingPlayer = true }
                    .onDisappear { player.presentingPlayer = false }
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environment(\.navigationStyle, .sidebar)
                    .handlesExternalEvents(preferring: Set(["player", "*"]), allowing: Set(["player", "*"]))
            }
            .handlesExternalEvents(matching: Set(["player", "*"]))

            Settings {
                SettingsView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            }
        #endif
    }

    func configure() {
        guard !Self.isForPreviews, !configured else {
            return
        }
        configured = true

        #if DEBUG
            SiestaLog.Category.enabled = .common
        #endif
        SDImageCodersManager.shared.addCoder(SDImageWebPCoder.shared)
        SDWebImageManager.defaultImageCache = PINCache(name: "stream.yattee.app")

        if !Defaults[.lastAccountIsPublic] {
            AccountsModel.shared.configureAccount()
        }

        if let countryOfPublicInstances = Defaults[.countryOfPublicInstances] {
            InstancesManifest.shared.setPublicAccount(countryOfPublicInstances, asCurrent: AccountsModel.shared.current.isNil)
        }

        if !AccountsModel.shared.current.isNil {
            player.restoreQueue()
        }

        if !Defaults[.saveRecents] {
            recents.clear()
        }

        let startupSection = Defaults[.startupSection]
        var section: TabSelection? = startupSection.tabSelection

        #if os(macOS)
            if section == .playlists {
                section = .search
            }
        #endif

        NavigationModel.shared.tabSelection = section ?? .search

        playlists.load()

        #if !os(macOS)
            player.updateRemoteCommandCenter()
        #endif

        if player.presentingPlayer {
            player.presentingPlayer = false
        }

        #if os(iOS)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if Defaults[.lockPortraitWhenBrowsing] {
                    Orientation.lockOrientation(.portrait, andRotateTo: .portrait)
                }
            }
        #endif

        URLBookmarkModel.shared.refreshAll()

        migrateHomeHistoryItems()
    }

    func migrateHomeHistoryItems() {
        guard Defaults[.homeHistoryItems] > 0 else { return }

        if favorites.addableItems().contains(where: { $0.section == .history }) {
            let historyItem = FavoriteItem(section: .history)
            favorites.add(historyItem)
            favorites.setListingStyle(.list, historyItem)
            favorites.setLimit(Defaults[.homeHistoryItems], historyItem)

            print("migrated home history items: \(favorites.limit(historyItem))")
        }

        Defaults[.homeHistoryItems] = -1
    }
}

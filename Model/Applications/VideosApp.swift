import Foundation

enum VideosApp: String, CaseIterable {
    case local
    case invidious
    case piped
    case peerTube

    var name: String {
        rawValue.capitalized
    }

    var supportsAccounts: Bool {
        self != .local
    }

    var supportsPopular: Bool {
        self == .invidious
    }

    var supportsSearchFilters: Bool {
        self == .invidious
    }

    var supportsSearchSuggestions: Bool {
        self != .peerTube
    }

    var supportsSubscriptions: Bool {
        supportsAccounts
    }

    var supportsTrendingCategories: Bool {
        self == .invidious
    }

    var supportsUserPlaylists: Bool {
        self != .local
    }

    var userPlaylistsEndpointIncludesVideos: Bool {
        self == .invidious
    }

    var userPlaylistsUseChannelPlaylistEndpoint: Bool {
        self == .piped
    }

    var userPlaylistsHaveVisibility: Bool {
        self == .invidious
    }

    var userPlaylistsAreEditable: Bool {
        self == .invidious
    }

    var hasFrontendURL: Bool {
        self == .piped
    }

    var searchUsesIndexedPages: Bool {
        self == .invidious
    }

    var supportsOpeningChannelsByName: Bool {
        self == .piped
    }

    var allowsDisablingVidoesProxying: Bool {
        self == .invidious
    }

    var supportsOpeningVideosByID: Bool {
        self != .local
    }
}

pragma Singleton

import Quickshell
import Quickshell.Services.Mpris

// MPRIS player manager singleton — same pattern as Caelestia services/Players.qml
// Change preferredPlayer to match your main player's identity
Singleton {
    id: root
    property bool isLiked: false

    readonly property list<MprisPlayer> list: Mpris.players.values

    readonly property MprisPlayer spotifyPlayer:
        list.find(p => p.identity === "Spotify") ?? null

    readonly property MprisPlayer browserPlayer:
        list.find(p => p.identity !== "Spotify") ?? null

    readonly property bool canSwitch: !!spotifyPlayer && !!browserPlayer

    PersistentProperties {
        id: persist
        reloadableId: "playerSwitcher"
        property string choice: "auto"
    }

    readonly property MprisPlayer active: {
        if (!canSwitch)
            return spotifyPlayer ?? browserPlayer ?? list [0] ?? null
        if (persist.choice === "browser") return browserPlayer
        if (persist.choice === "spotify") return spotifyPlayer
        // auto: prefer whichever is playing, otherwise fall back to Spotify
        if (browserPlayer?.isPlaying && !spotifyPlayer?.isPlaying)
            return browserPlayer
        return spotifyPlayer
    }

    readonly property bool isSpotifyActive: active === spotifyPlayer

    function togglePlayer() {
        persist.choice = isSpotifyActive ? "browser" : "spotify"
    }
}

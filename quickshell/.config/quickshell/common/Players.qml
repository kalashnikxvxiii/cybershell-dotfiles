pragma Singleton

import Quickshell
import Quickshell.Services.Mpris

// Singleton gestione player MPRIS — stesso pattern di Caelestia services/Players.qml
// Cambia preferredPlayer con l'identity del tuo player principale
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
        // auto: preferisce quello in riproduzione, altrimenti Spotify
        if (browserPlayer?.isPlaying && !spotifyPlayer?.isPlaying)
            return browserPlayer
        return spotifyPlayer
    }

    readonly property bool isSpotifyActive: active === spotifyPlayer

    function togglePlayer() {
        persist.choice = isSpotifyActive ? "browser" : "spotify"
    }
}

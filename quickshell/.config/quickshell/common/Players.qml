pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Services.Mpris

// MPRIS player manager singleton — same pattern as Caelestia services/Players.qml
// Change preferredPlayer to match your main player's identity
Singleton {
    id: root
    // Shared with the Radioport's own process (media.qml) through a file: set
    // here by the dashboard's lyrics, read there
    property bool isLiked: likedFile.text().trim() === "1"
    onIsLikedChanged: if ((likedFile.text().trim() === "1") !== isLiked) likedFile.setText(isLiked ? "1" : "0")

    readonly property list<MprisPlayer> list: Mpris.players.values

    readonly property MprisPlayer spotifyPlayer:
        list.find(p => p.identity === "Spotify") ?? null

    readonly property MprisPlayer browserPlayer:
        list.find(p => p.identity !== "Spotify") ?? null

    readonly property bool canSwitch: !!spotifyPlayer && !!browserPlayer

    // The picked player is shared by every Quickshell process (the Radioport
    // runs in its own, media.qml), so it lives in a file and not in memory
    QtObject {
        id: persist
        readonly property string choice: choiceFile.text().trim() || "auto"
    }
    FileView {
        id: choiceFile
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/qs-player-choice"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    FileView {
        id: likedFile
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/qs-player-liked"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    readonly property MprisPlayer active: {
        // A player picked from the radioport list, by bus name
        const picked = list.find(p => p.dbusName === persist.choice)
        if (picked) return picked
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
        choiceFile.setText(isSpotifyActive ? "browser" : "spotify")
    }

    function select(p) {
        if (p) choiceFile.setText(p === spotifyPlayer ? "spotify" : p.dbusName)
    }
}

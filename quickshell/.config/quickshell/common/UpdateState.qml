pragma Singleton
// UpdateState.qml -- what the HUD's update banners show. System updates come from the file
// arch-update's own timer keeps (cachy-update is the same tool); shell updates from
// scripts/shell-update-check.sh, which stays silent on the machine the shell is developed on.
// Dismissing hides a banner until its count changes.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int systemCount: 0
    property int shellCount: 0
    property bool hasCachy: false
    // Marked by ~/.config/quickshell/.no-shell-updates: only system updates here, in the big green form
    property bool devMachine: false
    property var dismissed: ({ system: 0, shell: 0 })

    readonly property bool showSystem: systemCount > 0 && dismissed.system !== systemCount
    readonly property bool showShell: shellCount > 0 && dismissed.shell !== shellCount

    readonly property string _script: Qt.resolvedUrl("../scripts/shell-update-check.sh").toString().replace("file://", "")
    readonly property string _root: Quickshell.env("HOME")

    function dismiss(kind) {
        const d = Object.assign({}, dismissed)
        d[kind] = kind === "shell" ? shellCount : systemCount
        dismissed = d
        dismissedFile.setText(JSON.stringify(d))
    }

    function upgrade(kind) {
        if (kind === "shell") {
            Quickshell.execDetached(["kitty", "--hold", "sh", "-c",
                'cd "$(git -C "$(dirname "$(readlink -f "$0")")" rev-parse --show-toplevel)" && git pull --ff-only && stow -R quickshell', _script])
        } else {
            Quickshell.execDetached(["kitty", root.hasCachy ? "cachy-update" : "arch-update"])
        }
    }

    FileView {
        id: systemFile
        path: root._root + "/.local/state/arch-update/last_updates_check"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.systemCount = text().split("\n").filter(l => l.trim() !== "").length
        onLoadFailed: root.systemCount = 0
    }

    FileView {
        id: dismissedFile
        path: root._root + "/.cache/qs-updates/dismissed.json"
        onLoaded: {
            try {
                root.dismissed = JSON.parse(text())
            } catch (e) {}
        }
    }

    Process {
        id: shellCheck
        command: ["bash", root._script]
        stdout: StdioCollector {
            onStreamFinished: root.shellCount = parseInt(text) || 0
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "mkdir -p \"$HOME/.cache/qs-updates\"; command -v cachy-update >/dev/null && echo cachy; [ -e \"$HOME/.config/quickshell/.no-shell-updates\" ] && echo dev"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.hasCachy = text.indexOf("cachy") >= 0
                root.devMachine = text.indexOf("dev") >= 0
            }
        }
    }

    // arch-update's timer replaces the file rather than writing into it, and the shell repo
    // has nothing to watch: both get looked at again now and then
    Timer {
        interval: 1800000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            systemFile.reload()
            shellCheck.running = true
        }
    }

    // ---------- Street cred: a moment of glory for what was just installed ----------
    IpcHandler {
        target: "streetcred"
        function test(name: string): void {
            root.credText = name.toUpperCase()
            credClear.restart()
        }
    }

    property string credText: ""
    property var _installed: []

    // The log is what every package tool ends up writing to, with nothing to install or hook
    Process {
        running: true
        // --pid: a shell killed at exit must not leave the tail behind
        command: ["sh", "-c", "exec tail -n0 -F --pid=$PPID /var/log/pacman.log"]
        stdout: SplitParser {
            onRead: line => {
                const m = line.match(/\[ALPM\] installed (\S+) /)
                if (m) {
                    root._installed.push(m[1])
                    credCollect.restart()
                }
            }
        }
    }
    // One transaction installs many packages: they make one banner
    Timer {
        id: credCollect
        interval: 1500
        onTriggered: {
            const names = root._installed
            root._installed = []
            root.credText = names.length === 1 ? names[0].toUpperCase() : names.length + " PACKAGES"
            Sounds.play("notify", "notif.mp3")
            credClear.restart()
        }
    }
    Timer {
        id: credClear
        interval: 7000
        onTriggered: root.credText = ""
    }
}

pragma Singleton
// LauncherMenus.qml — DATA layer of the launcher, ported from
// AndreaNec/Cyberpunk-quickshell (launcher/Menus.qml).
//
// An item is a plain object:
//   { id, name, comment?, glyph? | iconName?, keywords?, boost?,
//     run?: () => void,                       // leaf
//     children?: array | () => array,         // node
//     keepOpen?: bool }                       // leaf: don't close after run
//
// Network and Bluetooth read SonarState (its trackers are what make the
// Quickshell models publish anything); the launcher sets SonarState.menuView
// so the scan only runs while those submenus are on screen.

import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Io

Singleton {
    id: root

    function sh(cmd) {
        return () => Quickshell.execDetached(cmd);
    }

    // ---------- Apps ----------
    readonly property var apps: DesktopEntries.applications.values.filter(e => !e.noDisplay).map(e => ({
                id: "app:" + e.id,
                name: e.name,
                comment: e.comment || e.genericName || "",
                iconName: e.icon,
                keywords: (e.keywords || []).join(" "),
                run: () => e.execute()
            })).sort((a, b) => a.name.localeCompare(b.name))

    // ---------- Power ----------
    readonly property var power: [
        { id: "power:lock", name: "Lock", glyph: "", boost: 15, run: sh(["hyprlock"]) },
        { id: "power:suspend", name: "Suspend", glyph: "", boost: 15, keywords: "sleep", run: sh(["systemctl", "suspend"]) },
        { id: "power:hibernate", name: "Hibernate", glyph: "\uf2dc", boost: 15, run: sh(["systemctl", "hibernate"]) },
        // Not uwsm: the session ends through Hyprland itself
        { id: "power:logout", name: "Log out", glyph: "", boost: 15, keywords: "exit", run: () => HL.exit() },
        { id: "power:reboot", name: "Reboot", confirm: true, glyph: "", boost: 15, keywords: "restart", run: sh(["systemctl", "reboot"]) },
        { id: "power:off", name: "Power off", confirm: true, glyph: "", boost: 15, keywords: "shutdown", run: sh(["systemctl", "poweroff"]) }
    ]

    // ---------- Wi-Fi ----------
    readonly property var networks: {
        const rev = SonarState.netRev;   // re-evaluate when the list changes
        const items = [{
                id: "net:toggle",
                name: Networking.wifiEnabled ? "Turn wifi off" : "Turn wifi on",
                glyph: "",
                boost: 15,
                keepOpen: true,
                run: () => SonarState.toggleWifi()
            }];
        for (const net of SonarState.wifiNetworks()) {
            // Secured and unknown: the password is asked by the Sonar panel
            const needsPsk = !net.connected && !net.known && net.security !== WifiSecurityType.Open;
            items.push({
                id: "net:" + net.name,
                name: net.name,
                comment: net.connected ? "connected, select to disconnect" : needsPsk ? "secured, select to enter the password" : "select to connect",
                glyph: "",
                keepOpen: !needsPsk,
                run: () => {
                    if (net.connected) {
                        net.disconnect();
                    } else if (needsPsk) {
                        SonarState.openView("net", "");
                        SonarState.selectedKey = "wifi:" + net.name;
                    } else {
                        net.connect();
                    }
                }
            });
        }
        return items;
    }

    // ---------- Bluetooth ----------
    readonly property var bluetooth: {
        const rev = SonarState.btRev;
        const a = SonarState.adapter;
        if (!a)
            return [{ id: "bt:none", name: "No Bluetooth adapter", glyph: "", run: () => {} }];

        const items = [{
                id: "bt:toggle",
                name: a.enabled ? "Turn Bluetooth off" : "Turn Bluetooth on",
                glyph: "",
                boost: 15,
                keepOpen: true,
                run: () => SonarState.toggleAdapter()
            }];
        for (const d of SonarState.btDevices()) {
            // gets rid of the devices without real names
            if (d.name != d.deviceName)
                continue;
            items.push({
                id: "bt:" + d.address,
                name: d.name,
                comment: d.connected ? "Connected, select to disconnect" : (d.bonded ? "Bonded, select to connect" : "Disconnected, select to connect"),
                glyph: "",
                keepOpen: true,
                run: () => {
                    if (d.connected) d.disconnect();
                    else if (d.paired) d.connect();
                    else d.pair();
                }
            });
        }
        return items;
    }

    // ---------- System upgrade ----------
    property var pendingUpdates: []
    property string updatesStatus: "paru -Syu"

    function checkUpdates() {
        if (updateCheck.running)
            return;
        root.updatesStatus = "Checking…";
        updateCheck.running = true;
    }

    Process {
        id: updateCheck
        // checkupdates exits 2 when there is nothing to do and 1 on failure
        command: ["bash", "-c", "checkupdates 2>/dev/null; rc=$?; paru -Qua 2>/dev/null; [ $rc = 1 ] && echo __FAILED__; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l !== "");
                const failed = lines.includes("__FAILED__");
                const packages = lines.filter(l => l !== "__FAILED__");
                root.pendingUpdates = packages.map(l => {
                    const i = l.indexOf(" ");
                    return { id: "upgrade:" + l.slice(0, i), name: l.slice(0, i), comment: l.slice(i + 1), glyph: "\uf1b2", noSearch: true, keepOpen: true, run: () => {} };
                });
                root.updatesStatus = failed ? "Check failed, list may be incomplete"
                    : packages.length > 0 ? packages.length + " packages" : "System up to date";
            }
        }
    }

    readonly property var upgrade: [{
            id: "upgrade:run",
            name: "Upgrade all",
            comment: root.updatesStatus,
            glyph: "\uf0ed",
            boost: 15,
            run: sh(["kitty", "--hold", "paru", "-Syu"])
        }].concat(root.pendingUpdates)

    // ---------- Personal keybinds ----------
    property var userBinds: []

    function reloadUserBinds() {
        userBindsProc.running = true;
    }

    Process {
        id: userBindsProc
        running: true
        command: ["python3", Qt.resolvedUrl("../scripts/user-binds.py").toString().replace("file://", ""), "list"]
        stdout: StdioCollector {
            onStreamFinished: root.userBinds = JSON.parse(text)
        }
    }

    function shellQuote(args) {
        return args.map(a => /^[A-Za-z0-9_\/.:=-]+$/.test(a) ? a : "'" + a.replace(/'/g, "'\\''") + "'").join(" ");
    }

    // Rows holding `draft` open the bind editor instead of running something
    readonly property var addBindTargets: [{
            id: "keybinds:custom",
            name: "Custom command",
            comment: "Write the command yourself",
            glyph: "\uf120",
            boost: 15,
            noSearch: true,
            draft: { index: -1, name: "", keys: "", command: "" }
        }].concat(DesktopEntries.applications.values.filter(e => !e.noDisplay).map(e => ({
            id: "keybinds:app:" + e.id,
            name: e.name,
            comment: e.comment || e.genericName || "",
            iconName: e.icon,
            noSearch: true,
            draft: { index: -1, name: e.name, keys: "", command: root.shellQuote(e.command) }
        })).sort((a, b) => a.name.localeCompare(b.name)))

    readonly property var keybinds: [{
            id: "keybinds:sheet",
            name: "Cheatsheet",
            comment: "Every keybind",
            glyph: "\uf11c",
            boost: 15,
            run: () => Quickshell.execDetached(["qs", "ipc", "call", "cheatsheet", "toggle", LauncherState.screenName])
        }, {
            id: "keybinds:add",
            name: "Add bind",
            comment: "An app or a command on new keys",
            glyph: "\uf067",
            boost: 15,
            children: () => root.addBindTargets
        }].concat(root.userBinds.map((b, i) => ({
            id: "keybinds:user:" + i,
            name: b.name,
            comment: b.keys + "  ·  " + b.command,
            glyph: "\uf084",
            draft: { index: i, name: b.name, keys: b.keys, command: b.command }
        })))

    // ---------- Tree ----------
    readonly property var rootNode: ({
            id: "root",
            name: "Menu",
            children: () => [
                { id: "apps", name: "Apps", glyph: "", comment: "Installed applications", children: () => root.apps },
                { id: "power", name: "Power", glyph: "", comment: "Lock, suspend, reboot, power off", children: () => root.power },
                { id: "network", name: "Network", glyph: "", comment: "Wi-Fi and connections", children: () => root.networks },
                { id: "bluetooth", name: "Bluetooth", glyph: "", comment: "Adapter and devices", children: () => root.bluetooth },
                { id: "media", name: "Media", glyph: "󰝚", comment: "open Radioport", run: () => LauncherState.openMedia() },
                { id: "terminal", name: "Terminal", glyph: "\uf120", comment: "Open a kitty window", run: sh(["kitty"]) },
                { id: "keybinds", name: "Keybinds", glyph: "\uf11c", comment: "Cheatsheet and your own binds", children: () => root.keybinds },
                { id: "theme", name: "Theme", glyph: "\uf1fc", comment: "Wallpaper and colors", run: () => WallpaperState.togglePicker(LauncherState.screenName) },
                { id: "upgrade", name: "System upgrade", glyph: "\uf0ed", comment: "Pending packages, repos and AUR", onEnter: () => root.checkUpdates(), children: () => root.upgrade },
                // After the menu's fade: its surface would otherwise take the click
                { id: "kill", name: "Kill mode", glyph: "\uf05e", comment: "Click a window to kill it, Esc to cancel", keywords: "force quit", run: () => KillState.start() }
            ]
        })

    function childrenOf(node) {
        const c = node.children;
        return typeof c === "function" ? c() : (c || []);
    }

    // Every leaf under `node`, tagged with its breadcrumb in `path`
    function flatten(node, path) {
        let out = [];
        for (const it of childrenOf(node)) {
            if (it.noSearch)
                continue;
            if (it.children)
                out = out.concat(flatten(it, path ? path + " › " + it.name : it.name));
            else
                out.push(Object.assign({}, it, { path: path }));
        }
        return out;
    }

    // Memoized: only recomputed when apps/devices/etc. change, not on each keystroke
    readonly property var flat: flatten(rootNode, "")

    function search(pool, q) {
        const scored = [];
        for (const it of pool) {
            const n = it.name.toLowerCase();
            let s = 0;
            if (n.startsWith(q)) s = 100;
            else if (n.includes(q)) s = 60;
            else if ((it.keywords || "").toLowerCase().includes(q)) s = 40;
            else if ((it.comment || "").toLowerCase().includes(q)) s = 20;
            else if ((it.path || "").toLowerCase().includes(q)) s = 10;
            if (s > 0)
                scored.push({ it: it, s: s + (it.boost || 0) });
        }
        scored.sort((a, b) => b.s - a.s || a.it.name.localeCompare(b.it.name));
        return scored.map(x => x.it);
    }
}

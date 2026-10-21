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
        // Not uwsm: the session ends through Hyprland itself
        { id: "power:logout", name: "Log out", glyph: "", boost: 15, keywords: "exit", run: () => HL.exit() },
        { id: "power:reboot", name: "Reboot", glyph: "", boost: 15, keywords: "restart", run: sh(["systemctl", "reboot"]) },
        { id: "power:off", name: "Power off", glyph: "", boost: 15, keywords: "shutdown", run: sh(["systemctl", "poweroff"]) }
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

    // ---------- Tree ----------
    readonly property var rootNode: ({
            id: "root",
            name: "Menu",
            children: () => [
                { id: "apps", name: "Apps", glyph: "", comment: "Installed applications", children: () => root.apps },
                { id: "power", name: "Power", glyph: "", comment: "Lock, suspend, reboot, power off", children: () => root.power },
                { id: "network", name: "Network", glyph: "", comment: "Wi-Fi and connections", children: () => root.networks },
                { id: "bluetooth", name: "Bluetooth", glyph: "", comment: "Adapter and devices", children: () => root.bluetooth },
                { id: "media", name: "Media", glyph: "󰝚", comment: "open Radioport", run: () => LauncherState.openMedia() }
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

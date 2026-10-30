// CheatsheetModel.js -- turns `hyprctl binds -j` into the keymap's sections.
//
// Every bind describes itself as "SECTION|Name|Note" (keybindings-v2.lua). Binds
// sharing section, name and modifiers collapse into one row, so the four arrows
// or the ten workspace digits take a single line.
.pragma library

var MOD_BITS = [[64, "SUPER"], [8, "ALT"], [4, "CTRL"], [1, "SHIFT"]]

var KEY_LABELS = {
    "grave": "`", "slash": "/", "comma": ",", "period": ".", "equal": "=", "minus": "-",
    "left": "←", "right": "→", "up": "↑", "down": "↓",
    "SPACE": "SPACE", "Tab": "TAB", "Print": "PRINT", "Insert": "INS", "escape": "ESC",
    "mouse:272": "LMB", "mouse:273": "RMB", "mouse_down": "SCROLL", "mouse_up": "SCROLL",
    "XF86AudioRaiseVolume": "VOL+", "XF86AudioLowerVolume": "VOL-",
    "XF86AudioMute": "MUTE", "XF86AudioMicMute": "MIC",
    "XF86MonBrightnessUp": "BRI+", "XF86MonBrightnessDown": "BRI-",
    "XF86AudioNext": "NEXT", "XF86AudioPrev": "PREV",
    "XF86AudioPlay": "PLAY", "XF86AudioPause": "PAUSE"
}

function modsOf(mask) {
    var mods = []
    for (var i = 0; i < MOD_BITS.length; i++)
        if (mask & MOD_BITS[i][0]) mods.push(MOD_BITS[i][1])
    return mods
}

function keyLabel(key) {
    return KEY_LABELS[key] !== undefined ? KEY_LABELS[key] : key
}

// A full run of digits reads better as a range
function compactKeys(keys) {
    var digits = keys.filter(k => k >= "0" && k <= "9" && k.length === 1)
    if (digits.length === keys.length && keys.length >= 9) return ["1…0"]
    return keys
}

function build(binds) {
    var sections = []
    var byTitle = {}
    var rows = {}

    function sectionFor(title) {
        if (!byTitle[title]) {
            byTitle[title] = { title: title, entry: null, rows: [] }
            sections.push(byTitle[title])
        }
        return byTitle[title]
    }

    for (var i = 0; i < binds.length; i++) {
        var b = binds[i]
        if (!b.description) continue
        if (b.submap !== "" && b.key === "escape") continue

        var parts = b.description.split("|")
        var title = parts.length === 3 ? parts[0] : "OTHER"
        var name = parts.length === 3 ? parts[1] : b.description
        var note = parts.length === 3 ? parts[2] : ""
        var label = keyLabel(b.key)

        // "@TITLE" is the bind that opens a menu: it goes in the section header
        if (title.charAt(0) === "@") {
            var menu = sectionFor(title.substring(1))
            menu.entry = { mods: modsOf(b.modmask), keys: [label], note: note }
            continue
        }

        var id = title + "|" + name + "|" + b.modmask
        if (!rows[id]) {
            rows[id] = { section: title, name: name, note: note, mods: modsOf(b.modmask), keys: [] }
            sectionFor(title).rows.push(rows[id])
        }
        if (rows[id].keys.indexOf(label) < 0) rows[id].keys.push(label)
    }

    for (var id2 in rows) rows[id2].keys = compactKeys(rows[id2].keys)
    return sections.filter(s => s.rows.length > 0)
}

// Splits the sections, in order, over `count` columns so that the tallest column
// is as short as possible. A header weighs about as much as two rows.
function pack(sections, count) {
    var n = sections.length
    var cols = Math.max(1, Math.min(count, n))
    if (n === 0) return []
    var weight = sections.map(s => s.rows.length + 2)

    function span(a, b) {
        var w = 0
        for (var k = a; k < b; k++) w += weight[k]
        return w
    }

    // best[c][i]: lowest possible tallest column placing the first i sections in c columns
    var best = [], cut = []
    for (var c = 0; c <= cols; c++) {
        best.push([])
        cut.push([])
        for (var i = 0; i <= n; i++) {
            best[c].push(c === 0 && i === 0 ? 0 : Infinity)
            cut[c].push(0)
        }
    }
    for (c = 1; c <= cols; c++)
        for (i = 1; i <= n; i++)
            for (var j = 0; j < i; j++) {
                var v = Math.max(best[c - 1][j], span(j, i))
                if (v < best[c][i]) {
                    best[c][i] = v
                    cut[c][i] = j
                }
            }

    var result = []
    var end = n
    for (c = cols; c >= 1; c--) {
        var start = cut[c][end]
        result.unshift(sections.slice(start, end))
        end = start
    }
    return result
}

function matches(row, query, modFilter) {
    if (modFilter !== "" && row.mods.indexOf(modFilter) < 0) return false
    if (query === "") return true
    var q = query.toLowerCase()
    var text = (row.section + " " + row.name + " " + row.note + " "
        + row.mods.join(" ") + " " + row.keys.join(" ")).toLowerCase()
    return q.split(/\s+/).every(word => text.indexOf(word) >= 0)
}

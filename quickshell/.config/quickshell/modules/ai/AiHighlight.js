// AiHighlight.js - syntax highlighting and colour literals for the AI chat.
//
// No QSyntaxHighlighter reaches QML, so code is lexed here into the HTML
// subset of Text.RichText. One small lexer driven by a table per language:
// keywords, types, constants, comments and strings are what makes code
// readable at a glance, a real grammar would buy little on top.
//
// Colour literals (#rgb..#rrggbbaa, rgb(a), hsl(a)) are drawn in the colour
// they name, here and in the prose.
.pragma library

// Token colours: the shell's palette, lifted a little for 10px glyphs on a
// near-black slab
var C = {
    kw:    "#ff5ef0",   // magenta: the language itself
    type:  "#fcec0c",   // yellow: what things are
    fn:    "#25e1ed",   // cyan: what things do
    prop:  "#39c4b6",   // teal: keys and members
    str:   "#9cf27a",
    num:   "#ffa040",
    con:   "#ff5c7a",   // true / false / null
    com:   "#5f7380",
    meta:  "#f78b04",   // decorators, preprocessor, at-rules
    vari:  "#7fd8ff",   // $shell variables
    op:    "#ff5ef0",
    add:   "#39ff14",
    del:   "#ff3c5f",
    hunk:  "#25e1ed"
}

function esc(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
}

function span(cls, text) {
    if (text === "") return ""
    const it = cls === "com" ? "font-style:italic;" : ""
    return '<span style="' + it + 'color:' + C[cls] + '">' + esc(text) + '</span>'
}

// -- Colour literals ----------------------------------------

function _isHex(ch) { return (ch >= "0" && ch <= "9") || (ch >= "a" && ch <= "f") || (ch >= "A" && ch <= "F") }
function _isWord(ch) {
    return ch !== undefined && ((ch >= "0" && ch <= "9") || (ch >= "a" && ch <= "z")
        || (ch >= "A" && ch <= "Z") || ch === "_" || ch === "-")
}

// { r, g, b } in 0..255 and a in 0..1, or null
function parseColor(raw) {
    const s = raw.trim().toLowerCase()
    if (s[0] === "#") {
        const h = s.slice(1)
        for (const ch of h) if (!_isHex(ch)) return null
        const d = (i, n) => parseInt(n === 1 ? h[i] + h[i] : h.substr(i, 2), 16)
        if (h.length === 3 || h.length === 4)
            return { r: d(0, 1), g: d(1, 1), b: d(2, 1), a: h.length === 4 ? d(3, 1) / 255 : 1 }
        if (h.length === 6 || h.length === 8)
            return { r: d(0, 2), g: d(2, 2), b: d(4, 2), a: h.length === 8 ? d(6, 2) / 255 : 1 }
        return null
    }
    const open = s.indexOf("(")
    if (open < 0 || !s.endsWith(")")) return null
    const fn = s.slice(0, open)
    if (fn !== "rgb" && fn !== "rgba" && fn !== "hsl" && fn !== "hsla") return null
    const p = s.slice(open + 1, -1).split(/[\s,\/]+/).filter(x => x !== "")
    if (p.length < 3 || p.length > 4) return null
    const num = (x, scale) => x.endsWith("%") ? parseFloat(x) / 100 * scale : parseFloat(x)
    const a = p.length === 4 ? num(p[3], 1) : 1
    let r, g, b
    if (fn[0] === "r") {
        r = num(p[0], 255); g = num(p[1], 255); b = num(p[2], 255)
    } else {
        const hh = ((parseFloat(p[0]) % 360) + 360) % 360 / 360
        const ss = parseFloat(p[1]) / 100
        const ll = parseFloat(p[2]) / 100
        const q = ll < 0.5 ? ll * (1 + ss) : ll + ss - ll * ss
        const pp = 2 * ll - q
        const ch = t => {
            t = (t + 1) % 1
            if (t < 1 / 6) return pp + (q - pp) * 6 * t
            if (t < 1 / 2) return q
            if (t < 2 / 3) return pp + (q - pp) * (2 / 3 - t) * 6
            return pp
        }
        r = ch(hh + 1 / 3) * 255; g = ch(hh) * 255; b = ch(hh - 1 / 3) * 255
    }
    for (const v of [r, g, b, a]) if (!isFinite(v)) return null
    const k = v => Math.max(0, Math.min(255, v))
    return { r: k(r), g: k(g), b: k(b), a: Math.max(0, Math.min(1, a)) }
}

// The length of the colour literal starting at src[i], 0 if there is none.
// A literal must stand alone: "#fff" is one, "#fffx" and "a#fff" are not
function colorAt(src, i) {
    if (_isWord(src[i - 1]) || src[i - 1] === "#" || src[i - 1] === "&") return 0
    if (src[i] === "#") {
        let j = i + 1
        while (j < src.length && _isHex(src[j])) j++
        const n = j - i - 1
        if ((n !== 3 && n !== 4 && n !== 6 && n !== 8) || _isWord(src[j])) return 0
        // "#123" and "#1234" are issue numbers far more often than colours,
        // unless every digit is the same (#000, #fff-alikes)
        const h = src.slice(i + 1, j)
        let digits = true
        for (const ch of h) if (ch < "0" || ch > "9") digits = false
        if (digits && n <= 4 && h.split("").some(ch => ch !== h[0])) return 0
        return j - i
    }
    const low = src.substr(i, 5).toLowerCase()
    if (!(low.startsWith("rgb(") || low.startsWith("rgba(") || low.startsWith("hsl(") || low.startsWith("hsla(")))
        return 0
    const close = src.indexOf(")", i)
    if (close < 0 || close - i > 64) return 0
    return parseColor(src.slice(i, close + 1)) ? close + 1 - i : 0
}

// A colour literal in its own colour. Too dark to read on the slab, it turns
// into a chip of that colour instead. Alpha is left out: a 10% red would
// otherwise vanish, and the hue is what the eye is looking for
function swatch(raw) {
    const c = parseColor(raw)
    if (!c) return esc(raw)
    const hex = "#" + [c.r, c.g, c.b].map(v => ("0" + Math.round(v).toString(16)).slice(-2)).join("")
    const lum = (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) / 255
    if (Math.max(c.r, c.g, c.b) >= 150 && lum >= 0.15)
        return '<span style="color:' + hex + '">' + esc(raw) + '</span>'
    // The text keeps the hue, lightened: a near-black chip alone would vanish
    const lift = v => Math.round(v + (255 - v) * 0.65)
    const fg = "#" + [c.r, c.g, c.b].map(v => ("0" + lift(v).toString(16)).slice(-2)).join("")
    return '<span style="color:' + fg + '; background-color:' + hex + '">' + esc(raw) + '</span>'
}

// Plain text with its colour literals drawn, escaped. `cls` tints the rest
function withColors(text, cls) {
    let out = ""
    let run = ""
    const flush = () => { out += cls ? span(cls, run) : esc(run); run = "" }
    for (let i = 0; i < text.length;) {
        const n = (text[i] === "#" || text[i] === "r" || text[i] === "R" || text[i] === "h" || text[i] === "H")
            ? colorAt(text, i) : 0
        if (n > 0) {
            flush()
            out += swatch(text.substr(i, n))
            i += n
        } else {
            run += text[i++]
        }
    }
    flush()
    return out
}

// -- Languages ----------------------------------------------

function W(s) { const o = {}; for (const w of s.split(" ")) if (w) o[w] = true; return o }

const JS_KW = "break case catch class const continue debugger default delete do else export extends "
    + "finally for function if import in instanceof let new of return super switch this throw try typeof "
    + "var void while with yield async await static get set as from"
const JS_CON = "true false null undefined NaN Infinity"

const C_KW = "if else for while do switch case default break continue return goto sizeof typedef "
    + "struct union enum class public private protected virtual override final static const constexpr "
    + "inline extern volatile register template typename namespace using new delete this throw try "
    + "catch operator friend explicit noexcept import package extends implements interface abstract "
    + "synchronized throws instanceof var val fun when object data sealed open internal let func "
    + "guard defer in is as out ref readonly get set async await yield"
const C_TYPES = "void int char short long float double bool unsigned signed auto size_t ssize_t "
    + "uint8_t uint16_t uint32_t uint64_t int8_t int16_t int32_t int64_t string byte boolean "
    + "String Int Long Float Double Boolean Unit Any vec2 vec3 vec4 mat3 mat4 sampler2D uniform"

var LANGS = {
    js: { kw: W(JS_KW + " type interface enum implements readonly declare namespace keyof abstract public private protected"),
          con: W(JS_CON), types: W("string number boolean any unknown never object bigint symbol"),
          line: ["//"], block: [["/*", "*/"]], quotes: "\"'`", multi: "`", caps: true, at: true, props: true },
    qml: { kw: W(JS_KW + " property signal required readonly alias pragma on component"),
           con: W(JS_CON), types: W("int real double bool string var list color url date point rect size font variant"),
           line: ["//"], block: [["/*", "*/"]], quotes: "\"'`", multi: "`", caps: true, props: true },
    json: { kw: {}, con: W("true false null"), types: {}, line: ["//"], block: [["/*", "*/"]],
            quotes: "\"'", keys: true },
    python: { kw: W("and as assert async await break class continue def del elif else except finally for "
                + "from global if import in is lambda nonlocal not or pass raise return try while with yield match case"),
              con: W("True False None self cls"),
              types: W("int float str bool list dict set tuple bytes object type"),
              line: ["#"], block: [], triple: true, quotes: "\"'", caps: true, at: true },
    bash: { kw: W("if then else elif fi for while until do done case esac in function select return exit "
                + "local export readonly declare unset shift source alias time break continue"),
            con: W("true false"),
            types: W("echo printf cd test read eval exec trap wait kill pwd command builtin type set "
                + "sudo cat grep sed awk find ls rm cp mv mkdir chmod chown ln touch git curl systemctl "
                + "pacman paru yay qs hyprctl"),
            line: ["#"], block: [], quotes: "\"'", multi: "\"'", vars: true, dash: true },
    fish: { kw: W("if else for while in function return end begin switch case and or not set "
                + "break continue exit set_color status string contains test command builtin"),
            con: W("true false"), types: W("echo printf cd cat grep sed ls rm cp mv mkdir sudo git"),
            line: ["#"], block: [], quotes: "\"'", multi: "\"'", vars: true, dash: true },
    c: { kw: W(C_KW), con: W("true false NULL nullptr null nil"), types: W(C_TYPES),
         line: ["//"], block: [["/*", "*/"]], quotes: "\"'", caps: true, pre: true, at: true },
    rust: { kw: W("as break const continue crate else enum extern fn for if impl in let loop match mod move "
                + "mut pub ref return self Self static struct super trait type unsafe use where while async await dyn"),
            con: W("true false None Some Ok Err"),
            types: W("i8 i16 i32 i64 i128 isize u8 u16 u32 u64 u128 usize f32 f64 bool char str"),
            line: ["//"], block: [["/*", "*/"]], quotes: "\"", caps: true, macros: true },
    go: { kw: W("break case chan const continue default defer else fallthrough for func go goto if import "
              + "interface map package range return select struct switch type var"),
          con: W("true false nil iota"),
          types: W("int int8 int16 int32 int64 uint uint8 uint16 uint32 uint64 float32 float64 string bool byte rune error any"),
          line: ["//"], block: [["/*", "*/"]], quotes: "\"'`", multi: "`", caps: false },
    lua: { kw: W("and break do else elseif end for function goto if in local not or repeat return then until while"),
           con: W("true false nil self"), types: {},
           line: ["--"], block: [["--[[", "]]"]], quotes: "\"'", props: false },
    css: { kw: W("important inherit initial unset auto none"), con: {}, types: {},
           line: [], block: [["/*", "*/"]], quotes: "\"'", dash: true, props: true, at: true },
    sql: { kw: W("select from where and or not insert into values update set delete create table drop alter "
               + "add index primary key foreign references join left right inner outer on as group by order "
               + "having limit offset distinct union all case when then else end is null like in exists"),
           con: W("true false null"), types: W("int integer text varchar real boolean blob date timestamp"),
           line: ["--"], block: [["/*", "*/"]], quotes: "\"'", nocase: true },
    mermaid: { kw: W("graph flowchart subgraph end direction LR RL TB TD BT sequenceDiagram participant actor "
                   + "classDiagram stateDiagram stateDiagram-v2 erDiagram gantt pie journey gitGraph mindmap "
                   + "timeline note loop alt opt else par and rect activate deactivate title section class "
                   + "click style linkStyle classDef autonumber"),
               con: {}, types: {}, line: ["%%"], block: [], quotes: "\"", dash: false,
               brackets: { "[": "]", "{": "}", "(": ")", "|": "|" },
               ops: ["<-->", "-.->", "==>", "-->", "---", "--", "->>", "-->>", "->", "-x", "-)", "o--o", "x--x", "==="] },
    text: { kw: {}, con: {}, types: {}, line: [], block: [], quotes: "", plain: true }
}

var ALIAS = {
    js: "js", javascript: "js", jsx: "js", mjs: "js", cjs: "js", ts: "js", typescript: "js", tsx: "js",
    qml: "qml", json: "json", jsonc: "json", json5: "json", jsonl: "json",
    py: "python", python: "python", python3: "python",
    sh: "bash", bash: "bash", shell: "bash", zsh: "bash", console: "bash", shellsession: "bash",
    terminal: "bash", dockerfile: "bash", makefile: "bash", make: "bash", cmake: "bash", fish: "fish",
    c: "c", h: "c", cpp: "c", "c++": "c", cc: "c", hpp: "c", cxx: "c", java: "c", cs: "c", csharp: "c",
    kotlin: "c", kt: "c", swift: "c", glsl: "c", hlsl: "c", frag: "c", vert: "c", dart: "c", php: "c",
    rust: "rust", rs: "rust", go: "go", golang: "go", lua: "lua",
    css: "css", scss: "css", sass: "css", less: "css", qss: "css",
    html: "html", xml: "html", svg: "html", qrc: "html", xhtml: "html", vue: "html", ui: "html",
    yaml: "yaml", yml: "yaml", toml: "toml", ini: "toml", conf: "toml", cfg: "toml", desktop: "toml",
    properties: "toml", env: "toml",
    diff: "diff", patch: "diff", sql: "sql", mermaid: "mermaid", mmd: "mermaid",
    md: "md", markdown: "md"
}

// -- Lexers ---------------------------------------------------

function _id0(ch) { return (ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z") || ch === "_" }
function _id(ch, dash) {
    return ch !== undefined && (_id0(ch) || (ch >= "0" && ch <= "9") || (dash && ch === "-"))
}
// No trimStart in QML's JS engine
function _ltrim(s) { return s.replace(/^\s+/, "") }
function _digit(ch) { return ch >= "0" && ch <= "9" }
function _nextChar(src, j) { while (j < src.length && (src[j] === " " || src[j] === "\t")) j++; return src[j] }
function _prevChar(src, j) { j--; while (j >= 0 && (src[j] === " " || src[j] === "\t")) j--; return src[j] }

// The end of the string opened by src[i]
function _strEnd(src, i, close, multi) {
    let j = i + 1
    while (j < src.length) {
        if (src[j] === "\\") { j += 2; continue }
        if (src[j] === close) return j + 1
        if (src[j] === "\n" && !multi) return j
        j++
    }
    return src.length
}

function lex(src, sp) {
    let out = ""
    let run = ""
    const flush = () => { out += esc(run); run = "" }
    const emit = (cls, text) => { flush(); out += cls === "str" ? withColors(text, "str") : span(cls, text) }
    const n = src.length
    let i = 0

    outer:
    while (i < n) {
        const ch = src[i]

        if (!sp.plain) {
            for (const b of sp.block) {
                if (src.startsWith(b[0], i)) {
                    const j = src.indexOf(b[1], i + b[0].length)
                    const end = j < 0 ? n : j + b[1].length
                    emit("com", src.slice(i, end)); i = end; continue outer
                }
            }
            for (const lc of sp.line) {
                // "#" opens a comment only as a word of its own: $# and ${#a} do not
                if (src.startsWith(lc, i) && (lc !== "#" || i === 0 || " \t\n;".indexOf(src[i - 1]) >= 0)) {
                    let j = src.indexOf("\n", i)
                    if (j < 0) j = n
                    emit("com", src.slice(i, j)); i = j; continue outer
                }
            }
            if (sp.pre && ch === "#" && (i === 0 || src[i - 1] === "\n")) {
                let j = src.indexOf("\n", i)
                if (j < 0) j = n
                emit("meta", src.slice(i, j)); i = j; continue
            }
            if (sp.triple && (src.startsWith('"""', i) || src.startsWith("'''", i))) {
                const q = src.substr(i, 3)
                const j = src.indexOf(q, i + 3)
                const end = j < 0 ? n : j + 3
                emit("str", src.slice(i, end)); i = end; continue
            }
            if (sp.quotes.indexOf(ch) >= 0 && !(ch === "'" && _id(src[i - 1]) && sp !== LANGS.bash)) {
                const end = _strEnd(src, i, ch, (sp.multi ?? "").indexOf(ch) >= 0)
                const s = src.slice(i, end)
                if (sp.keys && _nextChar(src, end) === ":") emit("prop", s)
                else emit("str", s)
                i = end; continue
            }
            if (sp.brackets && sp.brackets[ch] !== undefined) {
                const close = sp.brackets[ch]
                let j = src.indexOf(close, i + 1)
                const nl = src.indexOf("\n", i)
                if (j >= 0 && (nl < 0 || j < nl)) {
                    flush(); out += esc(ch) + withColors(src.slice(i + 1, j), "str") + esc(close)
                    i = j + 1; continue
                }
            }
            if (sp.ops) {
                for (const o of sp.ops) {
                    if (src.startsWith(o, i)) { emit("op", o); i += o.length; continue outer }
                }
            }
        }

        const cn = colorAt(src, i)
        if (cn > 0) { flush(); out += swatch(src.substr(i, cn)); i += cn; continue }

        if (sp.plain) { run += ch; i++; continue }

        if ((_digit(ch) || (ch === "." && _digit(src[i + 1]) && src[i - 1] !== ".")) && !_id(src[i - 1], sp.dash)) {
            let j = i + 1
            while (j < n && (_id(src[j]) || src[j] === "%"
                || (src[j] === "." && _digit(src[j + 1])))) j++
            emit("num", src.slice(i, j)); i = j; continue
        }

        if (sp.vars && ch === "$") {
            let j = i + 1
            if (src[j] === "{") {
                const k = src.indexOf("}", j)
                j = k < 0 ? n : k + 1
            } else if (_id0(src[j])) {
                while (j < n && _id(src[j])) j++
            } else if (src[j] !== undefined && "0123456789?@#*!$-".indexOf(src[j]) >= 0) {
                j++
            }
            emit("vari", src.slice(i, j)); i = j; continue
        }

        if (sp.at && ch === "@" && _id0(src[i + 1])) {
            let j = i + 1
            while (j < n && (_id(src[j], sp.dash) || src[j] === ".")) j++
            emit("meta", src.slice(i, j)); i = j; continue
        }

        if (_id0(ch) || (sp.dash && ch === "-" && _id0(src[i + 1]) && !_id(src[i - 1]))) {
            let j = i + 1
            while (j < n && _id(src[j], sp.dash)) j++
            const w = src.slice(i, j)
            const key = sp.nocase ? w.toLowerCase() : w
            const next = _nextChar(src, j)
            let cls = ""
            if (sp.macros && src[j] === "!") { cls = "meta"; j++ }
            else if (sp.kw[key]) cls = "kw"
            else if (sp.con[key]) cls = "con"
            // A key before its type: QML's "color: ..." is a property, not the type
            else if (sp.props && next === ":" && src[src.indexOf(":", j) + 1] !== ":") cls = "prop"
            else if (sp.types[key]) cls = "type"
            else if (next === "(") cls = "fn"
            else if (_prevChar(src, i) === "." && src[i - 2] !== ".") cls = "prop"
            else if (sp.caps && ch >= "A" && ch <= "Z") cls = "type"
            if (cls) emit(cls, src.slice(i, j))
            else run += src.slice(i, j)
            i = j; continue
        }

        run += ch
        i++
    }
    flush()
    return out
}

function lexHtml(src) {
    let out = ""
    let i = 0
    const n = src.length
    while (i < n) {
        if (src.startsWith("<!--", i)) {
            const j = src.indexOf("-->", i)
            const end = j < 0 ? n : j + 3
            out += span("com", src.slice(i, end)); i = end; continue
        }
        if (src[i] === "<" && (_id0(src[i + 1]) || src[i + 1] === "/" || src[i + 1] === "!" || src[i + 1] === "?")) {
            let j = i + 1
            while (j < n && " \t\n>".indexOf(src[j]) < 0) j++
            out += esc("<") + span("kw", src.slice(i + 1, j))
            i = j
            // Attributes, up to the closing bracket
            while (i < n && src[i] !== ">") {
                const ch = src[i]
                if (ch === "\"" || ch === "'") {
                    const end = _strEnd(src, i, ch, true)
                    out += withColors(src.slice(i, end), "str"); i = end
                } else if (_id0(ch)) {
                    let k = i + 1
                    while (k < n && (_id(src[k], true) || src[k] === ":")) k++
                    out += span("prop", src.slice(i, k)); i = k
                } else {
                    out += esc(ch); i++
                }
            }
            if (i < n) { out += esc(">"); i++ }
            continue
        }
        if (src[i] === "&") {
            const j = src.indexOf(";", i)
            if (j > i && j - i < 10) { out += span("con", src.slice(i, j + 1)); i = j + 1; continue }
        }
        const cn = colorAt(src, i)
        if (cn > 0) { out += swatch(src.substr(i, cn)); i += cn; continue }
        out += esc(src[i]); i++
    }
    return out
}

// key: value / key = value, one line at a time; values lexed as JSON-ish
const VALUE = { kw: {}, con: W("true false null yes no on off True False None ~"), types: {},
    line: ["#"], block: [], quotes: "\"'", caps: false }

function lexConfig(src, sep) {
    return src.split("\n").map(line => {
        const t = line.trim()
        const lead = line.slice(0, line.length - _ltrim(line).length)
        if (t === "") return esc(line)
        if (t[0] === "#" || t[0] === ";") return esc(lead) + span("com", t)
        if (t[0] === "[" && sep === "=") return esc(lead) + span("type", t)
        let body = t
        let pre = ""
        if (sep === ":" && (body.startsWith("- ") || body === "-")) {
            pre = span("op", "-") + " "
            body = body.slice(2)
        }
        let k = -1
        for (let i = 0; i < body.length; i++) {
            const ch = body[i]
            if (ch === "\"" || ch === "'" || ch === " " && sep === ":") break
            if (ch === sep && (sep === "=" || body[i + 1] === undefined || body[i + 1] === " ")) { k = i; break }
        }
        if (k > 0) return esc(lead) + pre + span("prop", body.slice(0, k)) + esc(sep) + lex(body.slice(k + 1), VALUE)
        return esc(lead) + pre + lex(body, VALUE)
    }).join("\n")
}

// One block per line: added and removed lines are tinted edge to edge
function lexDiff(src) {
    return src.split("\n").map(l => {
        const line = (bg, text) => '<div style="white-space:pre-wrap' + (bg ? "; background-color:" + bg : "")
            + '">' + text + "</div>"
        if (l.startsWith("+++") || l.startsWith("---")) return line("", "<b>" + span("meta", l) + "</b>")
        if (l.startsWith("@@")) return line("", span("hunk", l))
        if (l.startsWith("+")) return line("#0c2a10", span("add", l))
        if (l.startsWith("-")) return line("#2e0a14", span("del", l))
        return line("", '<span style="color:#8a9aa6">' + esc(l === "" ? " " : l) + "</span>")
    }).join("")
}

function lexMarkdown(src) {
    return src.split("\n").map(l => {
        const t = _ltrim(l)
        if (t.startsWith("#")) return '<b>' + span("type", l) + '</b>'
        if (t.startsWith(">")) return span("com", l)
        if (t.startsWith("- ") || t.startsWith("* ") || t.startsWith("+ "))
            return esc(l.slice(0, l.length - t.length)) + span("op", t[0]) + withColors(t.slice(1))
        return withColors(l)
    }).join("\n")
}

// The language a fence names, lowercased and resolved; "" if unknown
function resolve(lang) {
    return ALIAS[(lang ?? "").trim().split(/\s+/)[0].toLowerCase()] ?? ""
}

// Code to RichText. Without a known language only the colour literals light up
function highlight(code, lang) {
    const l = resolve(lang)
    if (l === "html") return lexHtml(code)
    if (l === "yaml") return lexConfig(code, ":")
    if (l === "toml") return lexConfig(code, "=")
    if (l === "diff") return lexDiff(code)
    if (l === "md") return lexMarkdown(code)
    return lex(code, LANGS[l] ?? LANGS.text)
}

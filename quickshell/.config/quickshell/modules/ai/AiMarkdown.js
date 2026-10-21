// AiMarkdown.js - markdown to render blocks, for the AI chat.
//
// Text.MarkdownText hands everything to QTextDocument, which drops what it
// does not know (footnotes, math, <details>, definition lists) and draws the
// rest its own way: 40px list indents, quotes with no bar, inline code with no
// background. Here the block structure is parsed by hand and each block is
// drawn by AiMarkdownView; the inline content of a block becomes the HTML
// subset Text.RichText understands.
//
// parse(src) returns a flat list of blocks, each with a `depth` (list nesting):
//   h { level, html }        p { html }          li { marker, task, html }
//   code { lang, text }      table { html }      hr
//   math { html }            dt { html }         dd { html }
//   quote { kind, blocks }   details { summary, open, blocks }
//   notes { items: [{ n, html }] }
//
// parse(src, null, true) keeps every line break, as a chat box does: what a
// person typed on two lines stays on two lines
.pragma library
.import "AiHighlight.js" as H

var MONO = "JetBrainsMono Nerd Font"
var MATH = "DejaVu Serif"

const PUNCT = "\\`*_{}[]()#+-.!|~<>$=:\"'"

function _ltrim(s) { return s.replace(/^\s+/, "") }
function _indent(line) {
    let n = 0
    for (const ch of line) {
        if (ch === " ") n++
        else if (ch === "\t") n += 4
        else break
    }
    return n
}
function _alnum(ch) {
    return ch !== undefined && ((ch >= "0" && ch <= "9") || (ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z")
        || ch.charCodeAt(0) > 127)
}

// -- LaTeX ------------------------------------------------------
//
// Not a typesetter: symbols become their Unicode glyphs, ^ and _ become
// <sup>/<sub>, \frac and \sqrt get a typographic stand-in. Enough for the
// formulas a chat answer carries

const SYM = {
    alpha: "α", beta: "β", gamma: "γ", delta: "δ", epsilon: "ϵ", varepsilon: "ε", zeta: "ζ", eta: "η",
    theta: "θ", vartheta: "ϑ", iota: "ι", kappa: "κ", lambda: "λ", mu: "μ", nu: "ν", xi: "ξ", pi: "π",
    varpi: "ϖ", rho: "ρ", varrho: "ϱ", sigma: "σ", varsigma: "ς", tau: "τ", upsilon: "υ", phi: "ϕ",
    varphi: "φ", chi: "χ", psi: "ψ", omega: "ω",
    Gamma: "Γ", Delta: "Δ", Theta: "Θ", Lambda: "Λ", Xi: "Ξ", Pi: "Π", Sigma: "Σ", Upsilon: "Υ",
    Phi: "Φ", Psi: "Ψ", Omega: "Ω",
    int: "∫", iint: "∬", iiint: "∭", oint: "∮", sum: "∑", prod: "∏", coprod: "∐",
    infty: "∞", partial: "∂", nabla: "∇", pm: "±", mp: "∓", times: "×", cdot: "·", div: "÷", ast: "∗",
    star: "⋆", circ: "∘", bullet: "•", oplus: "⊕", otimes: "⊗",
    leq: " ≤ ", le: " ≤ ", geq: " ≥ ", ge: " ≥ ", neq: " ≠ ", ne: " ≠ ", approx: " ≈ ", equiv: " ≡ ",
    sim: " ∼ ", simeq: " ≃ ", cong: " ≅ ", propto: " ∝ ", ll: " ≪ ", gg: " ≫ ",
    to: " → ", rightarrow: " → ", leftarrow: " ← ", leftrightarrow: " ↔ ", Rightarrow: " ⇒ ",
    Leftarrow: " ⇐ ", Leftrightarrow: " ⇔ ", iff: " ⟺ ", implies: " ⟹ ", mapsto: " ↦ ",
    uparrow: "↑", downarrow: "↓", longrightarrow: " ⟶ ",
    in: " ∈ ", notin: " ∉ ", ni: " ∋ ", subset: " ⊂ ", subseteq: " ⊆ ", supset: " ⊃ ", supseteq: " ⊇ ",
    cup: " ∪ ", cap: " ∩ ", setminus: " ∖ ", emptyset: "∅", varnothing: "∅",
    forall: "∀", exists: "∃", nexists: "∄", neg: "¬", lnot: "¬", land: " ∧ ", wedge: " ∧ ", lor: " ∨ ",
    vee: " ∨ ", angle: "∠", perp: "⊥", parallel: "∥", degree: "°", prime: "′",
    ldots: "…", cdots: "⋯", dots: "…", vdots: "⋮", ddots: "⋱",
    hbar: "ℏ", ell: "ℓ", Re: "ℜ", Im: "ℑ", aleph: "ℵ", wp: "℘",
    langle: "⟨", rangle: "⟩", lceil: "⌈", rceil: "⌉", lfloor: "⌊", rfloor: "⌋", "|": "‖",
    "{": "{", "}": "}", "%": "%", "$": "$", "#": "#", "&": "&amp;", "_": "_",
    ",": "\u2009", ";": " ", ":": " ", " ": " ", "!": "", quad: "\u2003", qquad: "\u2003\u2003",
    "\\": "<br>"
}
const FUNCS = ["sin", "cos", "tan", "cot", "sec", "csc", "arcsin", "arccos", "arctan", "sinh", "cosh",
    "tanh", "log", "ln", "lg", "exp", "lim", "liminf", "limsup", "max", "min", "sup", "inf", "det",
    "dim", "ker", "deg", "gcd", "arg", "Pr", "mod", "bmod"]
const BB = { R: "ℝ", N: "ℕ", Z: "ℤ", Q: "ℚ", C: "ℂ", P: "ℙ", H: "ℍ" }
const ACCENT = { hat: "\u0302", bar: "\u0304", vec: "\u20d7", dot: "\u0307", ddot: "\u0308", tilde: "\u0303" }

function tex(s) {
    let i = 0
    const letter = ch => ch !== undefined && ((ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z"))
    const skip = () => { while (s[i] === " ") i++ }
    // The raw text of the next argument, for \text and friends
    const raw = () => {
        skip()
        if (s[i] !== "{") return s[i++] ?? ""
        let d = 0, j = i
        for (; j < s.length; j++) {
            if (s[j] === "{") d++
            else if (s[j] === "}" && --d === 0) break
        }
        const r = s.slice(i + 1, j)
        i = j + 1
        return r
    }
    function group() {
        skip()
        if (s[i] === "{") { i++; const h = seq("}"); i++; return h }
        return atom()
    }
    function seq(end) {
        let out = ""
        while (i < s.length && s[i] !== end) out += atom()
        return out
    }
    const up = t => '<span style="font-style:normal">' + H.esc(t) + '</span>'

    function atom() {
        const ch = s[i]
        // Past the end: a dangling ^, _ or \frac asks for an argument that is
        // not there, and H.esc(undefined) would throw out of the whole parse
        if (ch === undefined) { i++; return "" }
        if (ch === "\\") {
            let j = i + 1
            if (letter(s[j])) while (letter(s[j])) j++
            else j++
            const name = s.slice(i + 1, j)
            i = j
            if (name === "frac" || name === "dfrac" || name === "tfrac") {
                const a = group(), b = group()
                return "<sup>" + a + "</sup>⁄<sub>" + b + "</sub>"
            }
            if (name === "sqrt") {
                skip()
                let root = ""
                // An unclosed [ has no root: with k = -1, i would reset to 0
                // and re-enter this \sqrt until the stack overflows
                const k = s[i] === "[" ? s.indexOf("]", i) : -1
                if (k > 0) { root = tex(s.slice(i + 1, k)); i = k + 1 }
                return (root ? "<sup>" + root + "</sup>" : "") + '√<span style="text-decoration:overline">' + group() + "</span>"
            }
            if (name === "text" || name === "mathrm" || name === "textrm" || name === "operatorname"
                || name === "mbox" || name === "textup")
                return up(raw())
            if (name === "mathbf" || name === "textbf" || name === "boldsymbol" || name === "bm")
                return "<b>" + group() + "</b>"
            if (name === "mathit" || name === "textit" || name === "emph") return "<i>" + group() + "</i>"
            if (name === "mathbb") { const r = raw(); return BB[r] ?? H.esc(r) }
            if (name === "mathcal" || name === "mathscr" || name === "mathfrak") return group()
            if (name === "overline") return '<span style="text-decoration:overline">' + group() + "</span>"
            if (name === "underline") return "<u>" + group() + "</u>"
            if (ACCENT[name] !== undefined) return group() + ACCENT[name]
            if (name === "left" || name === "right" || name === "big" || name === "Big" || name === "bigg"
                || name === "Bigg" || name === "bigl" || name === "bigr" || name === "Bigl" || name === "Bigr") {
                skip()
                if (s[i] === ".") { i++; return "" }
                return atom()
            }
            if (name === "begin" || name === "end") { raw(); return "" }
            if (name === "displaystyle" || name === "limits" || name === "nolimits") return ""
            if (FUNCS.indexOf(name) >= 0) return up(name) + "\u2009"
            if (SYM[name] !== undefined) return SYM[name]
            return up("\\" + name)
        }
        if (ch === "{") { i++; const h = seq("}"); i++; return h }
        if (ch === "}") { i++; return "" }
        if (ch === "^") { i++; return "<sup>" + group() + "</sup>" }
        if (ch === "_") { i++; return "<sub>" + group() + "</sub>" }
        i++
        if (letter(ch)) return "<i>" + ch + "</i>"
        if (ch === " " || ch === "\n") return ""
        if (ch === "=" || ch === "<" || ch === ">") return " " + H.esc(ch) + " "
        if (ch === "-") return "−"
        if (ch === "'") return "′"
        if (ch === "&") return " "
        if (ch === "~") return "&nbsp;"
        return H.esc(ch)
    }
    return seq(undefined)
}

function mathSpan(src, size) {
    return '<span style="font-family:\'' + MATH + '\'; color:#d6e4ff' + (size ? "; font-size:" + size + "px" : "")
        + '">' + tex(src) + "</span>"
}

// -- Inline -------------------------------------------------------

function codeSpan(code) {
    return '<span style="font-family:\'' + MONO + '\'; font-size:11px; color:#9ff0e6; background-color:#0f2c2e">&nbsp;'
        + H.withColors(code) + "&nbsp;</span>"
}

// Text.linkColor does not reach rich text: the colour goes on the anchor
var LINK = "#00ffd2"
function link(href, inner) {
    return '<a href="' + H.esc(href) + '" style="color:' + LINK + '">' + inner + "</a>"
}

// Inline tags passed through, as Qt's rich text needs them
const TAGS = {
    sup: ["<sup>", "</sup>"], sub: ["<sub>", "</sub>"], b: ["<b>", "</b>"], strong: ["<b>", "</b>"],
    i: ["<i>", "</i>"], em: ["<i>", "</i>"], u: ["<u>", "</u>"], ins: ["<u>", "</u>"],
    s: ["<s>", "</s>"], del: ["<s>", "</s>"], strike: ["<s>", "</s>"], small: ["<small>", "</small>"],
    big: ["<big>", "</big>"],
    mark: ['<span style="color:#00060e; background-color:#fcec0c">', "</span>"],
    kbd: ['<span style="font-family:\'' + MONO + '\'; font-size:10px; color:#e8f0f4; background-color:#22303a">&nbsp;',
          "&nbsp;</span>"],
    code: ['<span style="font-family:\'' + MONO + '\'; font-size:11px; color:#9ff0e6; background-color:#0f2c2e">',
           "</span>"],
    br: ["<br>", ""]
}

// The closing run of `len` x `ch` for an opener ending at `from`, skipping
// code spans. A single * is not closed by **, a ** not by *
function _closer(s, from, ch, len) {
    let j = from
    while (j < s.length) {
        if (s[j] === "`") {
            let k = j
            while (s[k] === "`") k++
            const end = s.indexOf(s.slice(j, k), k)
            j = end < 0 ? k : end + (k - j)
            continue
        }
        if (s[j] === "\\") { j += 2; continue }
        if (s[j] === ch) {
            let k = j
            while (s[k] === ch) k++
            const run = k - j
            const ok = (run === len || run >= 3) && s[j - 1] !== " " && j > from
                && !(ch === "_" && _alnum(s[k]))
            if (ok) return k - len
            j = k
            continue
        }
        j++
    }
    return -1
}

// The matching bracket for s[i], counting nesting
function _match(s, i, open, close) {
    let d = 0
    for (let j = i; j < s.length; j++) {
        if (s[j] === "\\") { j++; continue }
        if (s[j] === open) d++
        else if (s[j] === close && --d === 0) return j
    }
    return -1
}

function inline(s, ctx) {
    let out = ""
    let run = ""
    const flush = () => { if (run !== "") { out += H.withColors(run); run = "" } }
    const n = s.length
    let i = 0
    while (i < n) {
        const ch = s[i]

        if (ch === "\\" && i + 1 < n && PUNCT.indexOf(s[i + 1]) >= 0 && s[i + 1] !== "(") {
            run += s[i + 1]; i += 2; continue
        }
        if (ch === "\n") { flush(); out += "<br>"; i++; continue }
        if (ch === "&") {
            const m = /^&(#\d{1,6}|#x[0-9a-fA-F]{1,6}|[a-zA-Z]{2,10});/.exec(s.slice(i, i + 12))
            if (m) { flush(); out += m[0]; i += m[0].length; continue }
        }

        if (ch === "`") {
            let k = i
            while (s[k] === "`") k++
            const ticks = s.slice(i, k)
            const close = s.indexOf(ticks, k)
            if (close >= 0) {
                let code = s.slice(k, close)
                if (code.length > 2 && code[0] === " " && code[code.length - 1] === " ") code = code.slice(1, -1)
                flush(); out += codeSpan(code); i = close + ticks.length; continue
            }
            run += ticks; i = k; continue
        }

        // $x$ is math only when it hugs its content: "$5 and $10" stays money
        if (ch === "$" && s[i + 1] !== "$" && s[i + 1] !== " " && s[i + 1] !== undefined) {
            let j = i + 1
            while (j < n) {
                j = s.indexOf("$", j)
                if (j < 0) break
                if (s[j - 1] !== " " && s[j - 1] !== "\\" && !(s[j + 1] >= "0" && s[j + 1] <= "9")) break
                j++
            }
            if (j > i + 1) { flush(); out += mathSpan(s.slice(i + 1, j)); i = j + 1; continue }
        }
        if (ch === "\\" && s[i + 1] === "(") {
            const j = s.indexOf("\\)", i + 2)
            if (j > 0) { flush(); out += mathSpan(s.slice(i + 2, j)); i = j + 2; continue }
        }

        if (ch === "*" || ch === "_") {
            let k = i
            while (s[k] === ch) k++
            const len = Math.min(3, k - i)
            const opens = s[k] !== undefined && s[k] !== " " && !(ch === "_" && _alnum(s[i - 1]))
            const j = opens ? _closer(s, k, ch, len) : -1
            if (j > 0) {
                flush()
                // A longer opener than the run used: the rest is literal
                run += s.slice(i, k - len)
                const inner = inline(s.slice(k, j), ctx)
                out += len === 1 ? "<i>" + inner + "</i>" : len === 2 ? "<b>" + inner + "</b>"
                    : "<b><i>" + inner + "</i></b>"
                i = j + len; continue
            }
            run += s.slice(i, k); i = k; continue
        }
        if (ch === "~" && s[i + 1] === "~") {
            const j = s.indexOf("~~", i + 2)
            if (j > i + 2) { flush(); out += "<s>" + inline(s.slice(i + 2, j), ctx) + "</s>"; i = j + 2; continue }
        }

        if (ch === "[" && s[i + 1] === "^") {
            const j = s.indexOf("]", i)
            const id = j > 0 ? s.slice(i + 2, j) : ""
            const num = ctx.notes[id]
            if (num !== undefined) {
                flush(); out += "<sup>" + link("fn:" + num, "[" + num + "]") + "</sup>"; i = j + 1; continue
            }
        }
        if (ch === "[" || (ch === "!" && s[i + 1] === "[")) {
            const img = ch === "!"
            const b = img ? i + 1 : i
            const close = _match(s, b, "[", "]")
            if (close > 0 && s[close + 1] === "(") {
                const pe = _match(s, close + 1, "(", ")")
                if (pe > 0) {
                    let href = s.slice(close + 2, pe).trim()
                    const sp = href.indexOf(" ")
                    if (sp > 0) href = href.slice(0, sp)
                    if (href.startsWith("<") && href.endsWith(">")) href = href.slice(1, -1)
                    const text = inline(s.slice(b + 1, close), ctx)
                    flush()
                    out += link(href, img ? "\uf03e " + (text || "image") : text)
                    i = pe + 1; continue
                }
            }
        }

        if (ch === "<") {
            const gt = s.indexOf(">", i)
            if (gt > 0) {
                const tag = s.slice(i + 1, gt)
                if (tag.startsWith("http://") || tag.startsWith("https://") || tag.startsWith("mailto:")) {
                    flush(); out += link(tag, H.esc(tag)); i = gt + 1; continue
                }
                const closing = tag[0] === "/"
                const name = (closing ? tag.slice(1) : tag).replace("/", "").trim().split(" ")[0].toLowerCase()
                if (TAGS[name] !== undefined) {
                    flush(); out += TAGS[name][closing ? 1 : 0]; i = gt + 1; continue
                }
            }
        }

        if ((ch === "h" || ch === "w") && !_alnum(s[i - 1]) && s[i - 1] !== "/"
            && (s.startsWith("https://", i) || s.startsWith("http://", i) || s.startsWith("www.", i))) {
            let j = i
            while (j < n && s[j] !== " " && s[j] !== "\n" && s[j] !== "<") j++
            // Trailing punctuation belongs to the sentence, a ")" only if unopened
            while (j > i && ".,;:!?'\"*_".indexOf(s[j - 1]) >= 0) j--
            if (s[j - 1] === ")" && s.slice(i, j).split("(").length <= s.slice(i, j).split(")").length - 1) j--
            const url = s.slice(i, j)
            flush()
            out += link(url.startsWith("www.") ? "https://" + url : url, H.esc(url))
            i = j; continue
        }

        run += ch
        i++
    }
    flush()
    return out
}

// -- Blocks -------------------------------------------------------

function _isFence(t) { return t.startsWith("```") || t.startsWith("~~~") }
function _isHr(t) {
    const c = t[0]
    if (c !== "-" && c !== "*" && c !== "_") return false
    let k = 0
    for (const ch of t) {
        if (ch === c) k++
        else if (ch !== " ") return false
    }
    return k >= 3
}
function _item(line) {
    const m = /^(\s*)([-*+]|\d{1,9}[.)])(\s+|$)(.*)$/.exec(line)
    if (!m) return null
    return { ind: _indent(m[1]), marker: m[2], text: m[4] }
}
function _isTableSep(t) { return /^\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?$/.test(t) && t.indexOf("-") >= 0 }
function _cells(t) {
    let r = t.trim()
    if (r.startsWith("|")) r = r.slice(1)
    if (r.endsWith("|") && !r.endsWith("\\|")) r = r.slice(0, -1)
    const out = []
    let cur = ""
    let code = false
    for (let i = 0; i < r.length; i++) {
        if (r[i] === "\\" && r[i + 1] === "|") { cur += "|"; i++; continue }
        if (r[i] === "`") code = !code
        if (r[i] === "|" && !code) { out.push(cur.trim()); cur = ""; continue }
        cur += r[i]
    }
    out.push(cur.trim())
    return out
}

function _table(rows, aligns, ctx) {
    const cell = (tag, txt, k, head) => '<' + tag + ' align="' + (aligns[k] ?? "left") + '"'
        + (head ? ' style="background-color:#0b2226; color:#25e1ed"' : "") + ">"
        + inline(txt ?? "", ctx) + "</" + tag + ">"
    let h = '<table cellspacing="0" cellpadding="5" border="1" style="border-color:#1f4a50; border-style:solid">'
    rows.forEach((r, ri) => {
        h += "<tr>" + aligns.map((a, k) => cell(ri === 0 ? "th" : "td", r[k], k, ri === 0)).join("") + "</tr>"
    })
    return h + "</table>"
}

const ALERTS = { note: "NOTE", tip: "TIP", important: "IMPORTANT", warning: "WARNING", caution: "CAUTION" }

function parse(src, ctx, breaks) {
    const lines = (src ?? "").replace(/\r/g, "").split("\n")

    // Footnote definitions first: references come before them in the text.
    // Nested parses (quotes, details) share the outer context
    const own = !ctx
    if (own) {
        ctx = { notes: {}, defs: [], breaks: breaks === true }
        for (let k = 0; k < lines.length; k++) {
            const m = /^\[\^([^\]]+)\]:\s?(.*)$/.exec(lines[k])
            if (!m) continue
            const body = [m[2]]
            lines[k] = null
            while (k + 1 < lines.length && lines[k + 1] !== null && /^\s{2,}\S/.test(lines[k + 1])) {
                body.push(lines[k + 1].trim()); lines[k + 1] = null; k++
            }
            ctx.notes[m[1]] = ctx.defs.length + 1
            ctx.defs.push(body.join(" "))
        }
    }

    const out = []
    let para = []          // lines of the open paragraph
    let paraDepth = 0
    let list = []          // marker indents of the open list items, outermost first
    let lastItem = null    // the last list item, for lazy continuation lines
    let blank = false

    const depthOf = ind => { let d = 0; for (const x of list) if (x < ind) d++; return d }
    const closePara = () => {
        if (para.length === 0) return
        // Two trailing spaces or a backslash end a line hard; any other break is a space
        let text = ""
        para.forEach((l, k) => {
            const hard = ctx.breaks || l.endsWith("  ") || l.endsWith("\\")
            const body = hard ? l.replace(/\s+$/, "").replace(/\\$/, "") : l
            text += body.trim() + (k === para.length - 1 ? "" : hard ? "\n" : " ")
        })
        out.push({ t: "p", depth: paraDepth, html: inline(text, ctx) })
        para = []
    }
    const endItem = () => {
        if (lastItem) lastItem.html = inline(lastItem.src, ctx)
        lastItem = null
    }

    for (let k = 0; k < lines.length; k++) {
        const line = lines[k]
        if (line === null) continue
        const t = line.trim()
        const ind = _indent(line)

        if (t === "") {
            closePara()
            endItem()
            blank = true
            continue
        }
        // Out of a list: a line back at the left margin after a blank one
        if (blank && list.length > 0 && ind === 0 && !_item(line)) list = []
        const wasBlank = blank
        blank = false

        if (_isFence(t)) {
            closePara()
            const fence = t.slice(0, 3)
            const lang = t.slice(3).replace(/[`~]/g, "").trim()
            const body = []
            let j = k + 1
            for (; j < lines.length; j++) {
                const l = lines[j]
                if (l === null) continue
                if (l.trim().startsWith(fence) && l.trim().replace(/[`~]/g, "") === "") break
                // Drop the fence's own indent from every line
                body.push(_indent(l) >= ind ? l.slice(Math.min(ind, l.length - _ltrim(l).length)) : _ltrim(l))
            }
            out.push({ t: "code", depth: depthOf(ind + 1), lang: lang, text: body.join("\n") })
            endItem()
            k = j
            continue
        }

        if (t.startsWith("$$") || t === "\\[") {
            closePara()
            const close = t === "\\[" ? "\\]" : "$$"
            let body = t.slice(2)
            let j = k
            if (!(body.trim().endsWith(close) && body.trim().length >= 2)) {
                for (j = k + 1; j < lines.length; j++) {
                    if (lines[j] === null) continue
                    if (lines[j].trim().endsWith(close)) { body += "\n" + lines[j]; break }
                    body += "\n" + lines[j]
                }
            }
            body = body.trim()
            if (body.endsWith(close)) body = body.slice(0, -close.length)
            out.push({ t: "math", depth: depthOf(ind + 1), html: mathSpan(body.trim()) })
            k = j
            continue
        }

        if (t.toLowerCase().startsWith("<details")) {
            closePara()
            let d = 0
            const body = []
            let j = k
            for (; j < lines.length; j++) {
                const l = lines[j]
                if (l === null) continue
                const lt = l.trim().toLowerCase()
                if (lt.startsWith("<details")) d++
                if (lt.indexOf("</details>") >= 0 && --d === 0) { body.push(l); break }
                body.push(l)
            }
            let all = body.join("\n")
            const isOpen = /^<details[^>]*\sopen/i.test(t)
            all = all.replace(/^\s*<details[^>]*>/i, "").replace(/<\/details>\s*$/i, "")
            let summary = "Details"
            const m = /<summary>([\s\S]*?)<\/summary>/i.exec(all)
            if (m) { summary = m[1].trim(); all = all.replace(m[0], "") }
            out.push({ t: "details", depth: depthOf(ind + 1), open: isOpen,
                summary: inline(summary, ctx), blocks: parse(all.trim(), ctx) })
            k = j
            continue
        }

        const hm = /^(#{1,6})\s+(.*?)\s*#*\s*$/.exec(t)
        if (hm && ind < 4) {
            closePara()
            list = []
            out.push({ t: "h", depth: 0, level: hm[1].length, html: inline(hm[2], ctx) })
            endItem()
            continue
        }

        // Setext: a paragraph underlined with === or --- is a heading
        if (para.length > 0 && (/^=+$/.test(t) || /^-+$/.test(t))) {
            const text = para.join(" ").trim()
            para = []
            out.push({ t: "h", depth: 0, level: t[0] === "=" ? 1 : 2, html: inline(text, ctx) })
            continue
        }

        if (_isHr(t)) {
            closePara()
            list = []
            endItem()
            out.push({ t: "hr", depth: 0 })
            continue
        }

        if (t.startsWith(">")) {
            closePara()
            const body = []
            let j = k
            for (; j < lines.length; j++) {
                const l = lines[j]
                if (l === null) continue
                const lt = l.trim()
                if (!lt.startsWith(">")) break
                body.push(lt.slice(1).startsWith(" ") ? lt.slice(2) : lt.slice(1))
            }
            let kind = ""
            const am = /^\[!(\w+)\]\s*$/.exec((body[0] ?? "").trim())
            if (am && ALERTS[am[1].toLowerCase()] !== undefined) { kind = am[1].toLowerCase(); body.shift() }
            out.push({ t: "quote", depth: depthOf(ind + 1), kind: kind, blocks: parse(body.join("\n"), ctx) })
            endItem()
            k = j - 1
            continue
        }

        if (t.indexOf("|") >= 0 && k + 1 < lines.length && lines[k + 1] !== null && _isTableSep(lines[k + 1].trim())) {
            closePara()
            const aligns = _cells(lines[k + 1]).map(c => {
                const l = c.startsWith(":"), r = c.endsWith(":")
                return l && r ? "center" : r ? "right" : "left"
            })
            const rows = [_cells(t)]
            let j = k + 2
            for (; j < lines.length; j++) {
                if (lines[j] === null || lines[j].trim() === "" || lines[j].indexOf("|") < 0) break
                rows.push(_cells(lines[j]))
            }
            out.push({ t: "table", depth: depthOf(ind + 1), html: _table(rows, aligns, ctx) })
            endItem()
            k = j - 1
            continue
        }

        const it = _item(line)
        if (it && !(para.length > 0 && !lastItem && /^\d/.test(it.marker) && it.marker !== "1." && it.marker !== "1)")) {
            closePara()
            endItem()
            while (list.length > 0 && list[list.length - 1] > it.ind) list.pop()
            if (list.length === 0 || list[list.length - 1] < it.ind) list.push(it.ind)
            let text = it.text
            let task = -1
            if (text.startsWith("[ ] ") || text === "[ ]") { task = 0; text = text.slice(4) }
            else if (text.startsWith("[x] ") || text.startsWith("[X] ")) { task = 1; text = text.slice(4) }
            const ordered = it.marker[0] >= "0" && it.marker[0] <= "9"
            lastItem = { t: "li", depth: list.length - 1, ordered: ordered,
                marker: ordered ? it.marker.replace(")", ".") : "", task: task, src: text, html: "" }
            out.push(lastItem)
            continue
        }

        // Definition list: "Term" then ": definition"
        if (t.startsWith(": ") && para.length === 1) {
            out.push({ t: "dt", depth: paraDepth, html: inline(para[0].trim(), ctx) })
            para = []
            out.push({ t: "dd", depth: paraDepth, html: inline(t.slice(2).trim(), ctx) })
            continue
        }

        // A line right under a list item, no blank between: the item goes on
        if (lastItem && !wasBlank) {
            lastItem.src += (ctx.breaks || lastItem.src.endsWith("  ") ? "\n" : " ") + t
            continue
        }

        if (para.length === 0) paraDepth = list.length > 0 ? depthOf(ind + 1) : 0
        para.push(line)
    }
    closePara()
    endItem()

    // Only the outermost parse owns the notes
    if (own && ctx.defs.length > 0)
        out.push({ t: "notes", depth: 0, items: ctx.defs.map((d, k) => ({ n: k + 1, html: inline(d, ctx) })) })
    return out
}

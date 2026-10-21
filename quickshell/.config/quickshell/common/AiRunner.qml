// AiRunner.qml - runs the shell snippets of the AI chat on request.
//
// A code block is rebuilt every time its message is re-laid out, and the
// transcript is re-laid out on every new turn: a turn, its process and its
// output live here instead, keyed by the snippet, so they outlive the block
// that started them. Two blocks with the same snippet share one run.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Fenced languages that are shell, and the interpreter for each
    readonly property var shells: ({
        bash: "bash", sh: "bash", shell: "bash", zsh: "bash",
        console: "bash", "shell-session": "bash", shellsession: "bash",
        fish: "fish"
    })

    // Bumped when a run is created or dropped, for the bindings that look one up
    property int revision: 0
    property var _runs: ({})

    // Kept output is the tail: a build log can run to megabytes
    readonly property int maxChars: 20000

    function isShell(lang) { return root.shells[(lang ?? "").toLowerCase()] !== undefined }

    function find(code) { return root._runs[code] ?? null }

    // A console transcript hold output too: only the prompted lines run
    function script(code, lang) {
        const l = (lang ?? "").toLowerCase()
        if (l !== "console" && l !== "shell-session" && l !== "shellsession") return code
        return code.split("\n").filter(x => /^\s*[$#] /.test(x))
            .map(x => x.replace(/^\s*[$#] /, "")).join("\n")
    }

    function run (code, lang, cwd) {
        let r = root.find(code)
        if (r === null) {
            r = runComp.createObject(root, { code: code })
            root._runs[code] = r
            root.revision++
        }
        if (r.running) return
        r.out = ""
        r.exitCode = -1
        r.stopped = false
        r.startedAt = Date.now()
        r.endedAt = 0
        r.workingDirectory = cwd || Quickshell.env("HOME")
        r.command = [root.shells[(lang ?? "").toLowerCase()] ?? "bash", "-c", root.script(code, lang)]
        r.running = true
    }

    function stop(code) {
        const r = root.find(code)
        if (r === null || !r.running) return
        r.stopped = true
        r.signal(15)
    }

    function clear(code) {
        const r = root.find(code)
        if (r === null || r.running) return
        delete root._runs[code]
        root.revision++
        r.destroy()
    }

    // Interactive commands (sudo, a pager, a prompt) need a real terminal
    function inTerminal(code, lang, cwd) {
        Quickshell.execDetached({
            command: ["kitty", "--hold", root.shells[(lang ?? "").toLowerCase()] ?? "bash",
                "-c", root.script(code, lang)],
            workingDirectory: cwd || Quickshell.env("HOME")
        })
    }

    Component {
        id: runComp

        Process {
            id: proc

            property string code: ""
            property string out: ""
            property int exitCode: -1
            property bool stopped: false
            property real startedAt: 0
            property real endedAt: 0

            // No colours, no pager, no prompt waiting on a stdin that is closed
            environment: ({ TERM: "dumb", NO_COLOR: "1", PAGER: "cat",
                GIT_PAGER: "cat", SYSTEMD_PAGER: "" })

            function append(line) {
                // Whatever escape codes still get through
                const t = proc.out + line.replace(/\x1b\[[0-9;?]*[ -\/]*[@-~]/g, "") + "\n"
                proc.out = t.length > root.maxChars ? t.slice(t.length - root.maxChars) : t
            }

            stdout: SplitParser { onRead: l => proc.append(l) }
            stderr: SplitParser { onRead: l => proc.append(l) }

            onExited: c => {
                proc.exitCode = c
                proc.endedAt = Date.now()
            }
        }
    }
}
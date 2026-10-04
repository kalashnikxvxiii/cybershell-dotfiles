// AiAccountDialog.qml - VIEW DETAILS: the whole account and usage panel.
//
// What the Claude extension shows in its Account & Usage dialog: the login,
// the plan limits, and what the usage on this machine says is eating into
// them. That last part is the CLI's own estimate from local sessions, with
// the extension's wording for each behaviour it measures
import QtQuick
import "../../common"
import "../../common/Colors.js" as CP

Item {
    id: root

    signal closed()

    readonly property color fg: "#d8e0e8"
    readonly property var session: AiState.session
    readonly property var account: root.session?.account ?? null
    readonly property var usage: root.session?.usage ?? null

    // "day" | "week": the window the contributing section reads
    property string span: "day"

    // `initialize` reports the provider, not the login method: a first-party
    // account with a subscription is a claude.ai login, without one an API key
    readonly property string authLabel: {
        const a = root.account
        if (!a) return "Not authenticated"
        switch (a.apiProvider) {
            case "firstParty": return a.subscriptionType ? "Claude AI" : "Anthropic API"
            case "bedrock": return "Amazon Bedrock"
            case "vertex": return "Google Vertex AI"
            case "foundry": return "Microsoft Foundry"
            default: return "Third Party"
        }
    }

    readonly property bool claudeAi: root.authLabel === "Claude AI"

    readonly property string manageUrl: {
        const t = root.usage?.subscription_type
        return (t === "team" || t === "enterprise")
            ? "https://claude.ai/admin-settings/usage" : "https://claude.ai/settings/usage"
    }

    // Below this a behaviour is noise, and it is left out
    readonly property int minPct: 10

    readonly property var behaviorText: ({
        cache_miss: {
            headline: p => p + "% of your usage hit a >100k-token cache miss",
            body: "Uncached input is expensive, and often happens when sending a message to a session that has gone idle. /compact before stepping away keeps the cold-start small." },
        long_context: {
            headline: p => p + "% of your usage was at >150k context",
            body: "Longer sessions are more expensive even when cached. /compact mid-task, /clear when switching to new tasks." },
        subagent_heavy: {
            headline: p => p + "% of your usage came from subagent-heavy sessions",
            body: "Each subagent runs its own requests. Be deliberate about spawning them \u2014 and consider configuring a cheaper model for simpler subagents." },
        high_parallel: {
            headline: p => p + "% of your usage was while 4+ sessions ran in parallel",
            body: "All sessions share one limit. If you don't need them all at once, queueing uses it more evenly." },
        cron: {
            headline: p => p + "% of your usage came from sessions active for 8+ hours",
            body: "These are often background/loop sessions. Continuous usage can add up quickly so make sure it is intentional." }
    })

    readonly property var groupText: [
        { key: "agents", title: "Subagents", prefix: "",
            headline: (p, n) => p + "% of your usage came from subagents under \"" + n + "\"",
            body: "If this runs frequently, consider configuring its subagents with a cheaper model or tightening their prompts." },
        { key: "skills", title: "Skills", prefix: "/",
            headline: (p, n) => p + "% of your usage came from /" + n,
            body: "Heavy skills can be scoped down or run with a cheaper model via skill frontmatter." },
        { key: "plugins", title: "Plugins", prefix: "",
            headline: (p, n) => p + "% of your usage came from the plugin \"" + n + "\"",
            body: "Review what this plugin contributes \u2014 its agents, skills, and MCP tools all count toward your limit." },
        { key: "mcp_servers", title: "MCP servers", prefix: "",
            headline: (p, n) => p + "% of your usage came from the MCP server \"" + n + "\"",
            body: "MCP tool results stay in context for the rest of the session. /compact to flush them, or disable servers you don't need." }
    ]

    function sorted(l) { return (l ?? []).slice().sort((a, b) => b.pct - a.pct) }

    function attributed(w) {
        return root.groupText.some(g => (w[g.key] ?? []).length > 0)
    }

    function worthShowing(w) {
        if (!w) return false
        return (w.behaviors ?? []).some(b => root.behaviorText[b.key] && b.pct >= root.minPct)
            || root.attributed(w)
    }

    readonly property var behaviors: root.usage?.behaviors ?? null
    readonly property bool showContrib: root.behaviors !== null
        && (root.worthShowing(root.behaviors.day) || root.worthShowing(root.behaviors.week))
    readonly property var win: root.behaviors?.[root.span] ?? null

    // One line and one piece of advice per finding over the threshold
    readonly property var findings: {
        const w = root.win
        if (!w) return []
        const out = []
        for (const b of (w.behaviors ?? [])) {
            const t = root.behaviorText[b.key]
            if (t && b.pct >= root.minPct)
                out.push({ headline: t.headline(Math.round(b.pct)), body: t.body })
        }
        for (const g of root.groupText) {
            const top = root.sorted(w[g.key])[0]
            if (top && top.pct >= root.minPct)
                out.push({ headline: g.headline(Math.round(top.pct), top.name), body: g.body })
        }
        return out
    }

    // The attribution tables, eight rows each at most
    readonly property var groups: {
        const w = root.win
        if (!w) return []
        return root.groupText.filter(g => (w[g.key] ?? []).length > 0).map(g => {
            const s = root.sorted(w[g.key])
            return { title: g.title, more: Math.max(0, s.length - 8),
                rows: s.slice(0, 8).map(x => ({ name: g.prefix + x.name, pct: Math.round(x.pct) })) }
        })
    }

    // The scrim: a click outside the card closes it
    Rectangle {
        anchors.fill: parent
        color: CP.alpha(CP.black, 0.55)

        MouseArea {
            anchors.fill: parent
            onClicked: root.closed()
        }
    }

    Item {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 12
        width: Math.min(parent.width - 16, 420)
        height: Math.min(parent.height - 24, titleRow.anchors.margins + titleRow.height
            + flick.anchors.topMargin + flick.contentHeight + flick.anchors.bottomMargin)

        CutShape {
            anchors.fill: parent
            fillColor: CP.alpha(CP.void2, 0.98)
            strokeColor: CP.alpha(CP.magenta, 0.50)
            strokeWidth: 1
            inset: 0.5
            cutTopRight: 18
            cutBottomLeft: 18
        }

        // Takes the clicks, or they would reach the scrim and close the card
        MouseArea { anchors.fill: parent }

        Item {
            id: titleRow
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.margins: 14
            height: 22

            Rectangle {
                id: bar
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: 4
                color: CP.magenta
            }

            Text {
                anchors.left: bar.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "ACCOUNT & USAGE"
                font.family: "Oxanium"
                font.pixelSize: 13
                font.letterSpacing: 3
                font.bold: true
                color: CP.magenta
            }

            AiIconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                frame: false
                glyph: "\uf00d"
                glyphSize: 11
                accent: CP.magenta
                onTriggered: root.closed()
            }
        }

        Flickable {
            id: flick
            anchors { top: titleRow.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
            anchors.topMargin: 16
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.bottomMargin: 14
            contentWidth: width
            contentHeight: body.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Column {
                id: body
                width: flick.width
                spacing: 10

                // -- Account -----------------------------
                SectionTitle { text: "ACCOUNT" }

                InfoRow { label: "Auth method"; value: root.authLabel }
                InfoRow {
                    visible: value !== ""
                    label: "Email"
                    value: root.account?.email ?? ""
                }
                InfoRow {
                    visible: value !== ""
                    label: "Organization"
                    value: root.account?.organization ?? ""
                }
                InfoRow {
                    visible: value !== ""
                    label: "Plan"
                    value: root.account?.subscriptionType ?? ""
                }

                // -- Usage -------------------------------
                Item { width: 1; height: 4 }
                SectionTitle { text: "USAGE" }

                Caption {
                    visible: text !== ""
                    text: root.session?.usageNote ?? ""
                }

                Text {
                    visible: (root.session?.usageError ?? "") !== ""
                    text: "RETRY"
                    font.family: "Oxanium"
                    font.pixelSize: 9
                    font.letterSpacing: 2
                    font.bold: true
                    color: retry.containsMouse ? CP.cyan : CP.alpha(CP.cyan, 0.60)

                    MouseArea {
                        id: retry
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.session.requestUsage()
                    }
                }

                Repeater {
                    model: root.session?.usageWindows ?? []

                    AiUsageBar {
                        required property var modelData
                        width: body.width
                        label: modelData.label
                        utilization: modelData.utilization
                        resetsAt: modelData.resetsAt
                    }
                }

                Text {
                    visible: root.claudeAi
                    text: "Manage usage on claude.ai \u2197"
                    font.family: "Oxanium"
                    font.pixelSize: 11
                    font.underline: manage.containsMouse
                    color: manage.containsMouse ? CP.cyan : CP.alpha(root.fg, 0.55)
                    Behavior on color { ColorAnimation { duration: 100 } }

                    MouseArea {
                        id: manage
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.openUrlExternally(root.manageUrl)
                    }
                }

                // -- What is contributing ----------------
                Column {
                    width: parent.width
                    spacing: 10
                    visible: root.showContrib

                    Item { width: 1; height: 4 }
                    SectionTitle { text: "WHAT\u2019S CONTRIBUTING TO YOUR LIMITS USAGE?" }

                    Row {
                        spacing: 0

                        Repeater {
                            model: [{ key: "day", label: "DAY" }, { key: "week", label: "WEEK" }]

                            Item {
                                required property var modelData
                                readonly property bool on: root.span === modelData.key
                                width: 52
                                height: 20

                                Rectangle {
                                    anchors.fill: parent
                                    color: parent.on ? CP.alpha(CP.magenta, 0.18) : "transparent"
                                    border.width: 1
                                    border.color: CP.alpha(CP.magenta, parent.on ? 0.70 : 0.25)
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: parent.modelData.label
                                    font.family: "Oxanium"
                                    font.pixelSize: 9
                                    font.letterSpacing: 2
                                    font.bold: true
                                    color: parent.on ? CP.magenta : CP.alpha(root.fg, 0.45)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.span = parent.modelData.key
                                }
                            }
                        }
                    }

                    Caption {
                        text: "Approximate, based on local sessions on this machine \u2014 does not include other devices or claude.ai"
                    }

                    Caption {
                        text: "Last " + (root.span === "day" ? "24h" : "7d")
                            + " \u00b7 these are independent characteristics of your usage, not a breakdown"
                    }

                    Caption {
                        visible: root.findings.length === 0 && root.groups.length === 0
                        text: "Nothing over " + root.minPct + "% in this period \u2014 try the other window."
                    }

                    Repeater {
                        model: root.findings

                        Column {
                            required property var modelData
                            width: body.width
                            spacing: 3

                            Text {
                                width: parent.width
                                text: parent.modelData.headline
                                wrapMode: Text.Wrap
                                font.family: "Oxanium"
                                font.pixelSize: 12
                                color: root.fg
                            }

                            Text {
                                width: parent.width
                                leftPadding: 10
                                text: parent.modelData.body
                                wrapMode: Text.Wrap
                                font.family: "Oxanium"
                                font.pixelSize: 10
                                color: CP.alpha(root.fg, 0.55)
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 3
                        visible: root.groups.length === 0

                        Text {
                            text: "Skills, subagents, plugins, and MCP servers"
                            font.family: "Oxanium"
                            font.pixelSize: 12
                            font.bold: true
                            color: root.fg
                        }

                        Caption { text: "No attribution data yet \u00b7 accumulates as you use Claude" }
                    }

                    Repeater {
                        model: root.groups

                        Column {
                            id: group
                            required property var modelData
                            width: body.width
                            spacing: 3

                            InfoRow {
                                label: group.modelData.title
                                value: "% of usage"
                            }

                            Repeater {
                                model: group.modelData.rows

                                InfoRow {
                                    required property var modelData
                                    label: modelData.name
                                    value: modelData.pct + "%"
                                }
                            }

                            Caption {
                                visible: group.modelData.more > 0
                                text: "\u2026 " + group.modelData.more + " more"
                            }
                        }
                    }
                }
            }
        }

        // Thin magenta rail, only when the content overflows
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 5
            width: 2
            visible: flick.contentHeight > flick.height
            y: flick.y + flick.visibleArea.yPosition * flick.height
            height: Math.max(18, flick.visibleArea.heightRatio * flick.height)
            color: CP.alpha(CP.magenta, flick.moving ? 0.55 : 0.25)
        }
    }

    // -- Pieces ----------------------------------------
    //
    // Inline components do not see the file's ids: the colours are spelled out

    component SectionTitle: Text {
        font.family: "Oxanium"
        font.pixelSize: 8
        font.letterSpacing: 2
        font.bold: true
        color: CP.alpha("#d8e0e8", 0.38)
    }

    component Caption: Text {
        width: parent ? parent.width : 0
        wrapMode: Text.Wrap
        font.family: "Oxanium"
        font.pixelSize: 9
        color: CP.alpha("#d8e0e8", 0.40)
    }

    component InfoRow: Item {
        id: row
        property string label: ""
        property string value: ""
        width: parent ? parent.width : 0
        height: Math.max(rowLabel.implicitHeight, rowValue.implicitHeight)

        Text {
            id: rowLabel
            anchors.left: parent.left
            text: row.label
            font.family: "Oxanium"
            font.pixelSize: 11
            color: CP.alpha("#d8e0e8", 0.45)
        }

        Text {
            id: rowValue
            anchors.left: rowLabel.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            horizontalAlignment: Text.AlignRight
            text: row.value
            elide: Text.ElideLeft
            font.family: "Oxanium"
            font.pixelSize: 11
            color: "#d8e0e8"
        }
    }
}

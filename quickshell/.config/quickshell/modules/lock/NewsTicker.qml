// NewsTicker.qml -- a NETWATCH newsfeed across the lock screen (copy of the one in the SDDM theme). It
// fetches the BBC World headlines itself when the lock starts. Hidden
// until a fetch succeeds; retries every 30 s while offline, then refreshes every 15 min.
import QtQuick

Item {
    id: root

    property color accent: "#fcec0c"
    property color textColor: "#25e1ed"
    property string fontLabels: "Oxanium"
    property string fontData: "Oxanium"
    // Scroll speed, px per second
    property real speed: 90

    property var headlines: []
    readonly property string feed: "https://feeds.bbci.co.uk/news/world/rss.xml"

    implicitHeight: 30
    visible: root.headlines.length > 0

    function decode(s) {
        return s.replace("<![CDATA[", "").replace("]]>", "")
            .split("&amp;").join("&").split("&quot;").join("\"").split("&#39;").join("'")
            .split("&apos;").join("'").split("&lt;").join("<").split("&gt;").join(">").trim()
    }

    // Titles of the <item>s; the channel's own title comes before the first one
    function parse(xml) {
        const out = []
        const items = xml.split("<item>").slice(1)
        for (const it of items) {
            const a = it.indexOf("<title>"), b = it.indexOf("</title>")
            if (a >= 0 && b > a) {
                const t = root.decode(it.slice(a + 7, b))
                if (t !== "")
                    out.push(t.toUpperCase())
            }
            if (out.length === 12)
                break
        }
        return out
    }

    function fetch() {
        const x = new XMLHttpRequest()
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE)
                return
            const got = x.status === 200 ? root.parse(x.responseText) : []
            if (got.length > 0)
                root.headlines = got
            retry.interval = got.length > 0 ? 15 * 60 * 1000 : 30 * 1000
            retry.restart()
        }
        x.open("GET", root.feed)
        x.send()
    }

    Timer {
        id: retry
        onTriggered: root.fetch()
    }
    Component.onCompleted: root.fetch()

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.6)
    }

    // Label, cut on its right side
    Item {
        id: label
        width: labelText.implicitWidth + 40
        height: parent.height
        z: 1
        Canvas {
            anchors.fill: parent
            onPaint: {
                const c = getContext("2d")
                c.reset()
                c.fillStyle = root.accent
                c.beginPath()
                c.moveTo(0, 0)
                c.lineTo(width, 0)
                c.lineTo(width - height, height)
                c.lineTo(0, height)
                c.closePath()
                c.fill()
            }
        }
        Text {
            id: labelText
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            text: "NETWATCH // NEWSFEED"
            color: "#000000"
            font.family: root.fontLabels
            font.pixelSize: 12
            font.bold: true
            font.letterSpacing: 2
        }
    }

    Item {
        anchors.left: label.right
        anchors.right: parent.right
        height: parent.height
        clip: true

        Text {
            id: run
            anchors.verticalCenter: parent.verticalCenter
            text: root.headlines.join("     ◆     ")
            color: root.textColor
            font.family: root.fontData
            font.pixelSize: 13
            font.letterSpacing: 1
            onTextChanged: scroll.restart()

            NumberAnimation on x {
                id: scroll
                from: run.parent.width
                to: -run.implicitWidth
                duration: Math.max(1, (run.parent.width + run.implicitWidth) / root.speed * 1000)
                loops: Animation.Infinite
                running: root.visible
            }
        }
    }
}

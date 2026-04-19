import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../common/Colors.js" as CP
import "../../common"

// Weather Tab: icon + temperature + 5-day forecast
// Adapted from Caelestia modules/dashboard/Weather.qml
// Uses wttr.in JSON API (no API key needed)

Item {
    id: root

    implicitWidth: 520
    implicitHeight: 440

    property string city: ""
    property string condition: ""
    property string weatherIcon: "☁"
    property string tempStr: "--°"
    property string feelsLike: "--°"
    property string humidity: "--%"
    property string windSpeed: "-- km/h"
    property string sunrise: "--:--"
    property string sunset: "--:--"
    property var forecast: []
    property bool loading: true
    property bool hasError: false

    Component.onCompleted: loadWeather()

    function loadWeather() {
        loading = true
        hasError = false
        weatherProc.running = true
    }

    Process {
        id: weatherProc
        command: ["bash", "-c",
            "curl -s --max-time 8 'https://wttr.in/?format=j1' 2>/dev/null || echo 'ERROR'"
        ]
        running: false

        property string buffer: ""

        stdout: SplitParser {
            onRead: data => { weatherProc.buffer += data }
        }

        onRunningChanged: {
            if (running) buffer = ""
            if (!running && buffer !== "") {
                root.loading = false
                if (buffer.startsWith("ERROR") || buffer.length < 10) {
                    root.hasError = true
                    buffer = ""
                    return
                }
                try {
                    const data = JSON.parse(buffer)
                    const cur  = data.current_condition[0]
                    const area = data.nearest_area[0]

                    root.city      = area.areaName[0].value + ", " + area.country[0].value
                    root.condition = cur.weatherDesc[0].value
                    root.tempStr   = cur.temp_C + "°C"
                    root.feelsLike = cur.FeelsLikeC + "°C"
                    root.humidity  = cur.humidity + "%"
                    root.windSpeed = cur.windspeedKmph + " km/h"

                    // Simplified weather icon
                    const code = parseInt(cur.weatherCode)
                    if (code === 113)         root.weatherIcon = "☀"
                    else if (code <= 116)     root.weatherIcon = "⛅"
                    else if (code <= 122)     root.weatherIcon = "☁"
                    else if (code <= 200)     root.weatherIcon = "🌫"
                    else if (code <= 314)     root.weatherIcon = "🌧"
                    else if (code <= 395)     root.weatherIcon = "❄"
                    else                      root.weatherIcon = "⛈"

                    // Sunrise/Sunset from the first day
                    const w0 = data.weather[0]
                    root.sunrise = w0.astronomy[0].sunrise
                    root.sunset  = w0.astronomy[0].sunset

                    // 5-day forecast
                    root.forecast = data.weather.slice(0, 5).map((d, i) => ({
                        date: new Date(d.date),
                        icon: iconForCode(parseInt(d.hourly[4]?.weatherCode ?? 113)),
                        maxC:  d.maxtempC + "°",
                        minC:  d.mintempC + "°"
                    }))
                } catch (e) {
                    root.hasError = true
                }
                buffer = ""
            }
        }
    }

    function iconForCode(code) {
        if (code === 113)       return "☀"
        if (code <= 116)        return "⛅"
        if (code <= 122)        return "☁"
        if (code <= 200)        return "🌫"
        if (code <= 314)        return "🌧"
        if (code <= 395)        return "❄"
        return "⛈"
    }

    // Refresh timer every 30 minutes
    Timer {
        interval: 1800000
        running: root.visible
        repeat: true
        onTriggered: root.loadWeather()
    }

    // -- Layout --
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        // Loading / Error
        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: root.loading || root.hasError
            text: root.loading ? "Loading weather..." : "Could not load weather data"
            font.family: "Oxanium"
            font.pixelSize: 12
            color: root.hasError ? CP.red : Colours.textSecondary
        }

        // Header: city + date + sunrise/sunset
        RowLayout {
            Layout.fillWidth: true
            visible: !root.loading && !root.hasError

            Column {
                spacing: 2
                Text {
                    text: root.city
                    font.family: "Oxanium"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: Colours.textPrimary
                }
                Text {
                    text: new Date().toLocaleDateString(Qt.locale(), "dddd, MMMM d")
                    font.family: "Oxanium"
                    font.pixelSize: 9
                    color: Colours.textSecondary
                }
            }

            Item { Layout.fillWidth: true }

            Row {
                spacing: 16
                WeatherStat { icon: "☀"; label: "Sunrise"; value: root.sunrise; colour: Colours.accentPrimary }
                WeatherStat { icon: "🌙"; label: "Sunset";  value: root.sunset;  colour: Colours.accentPrimary }
            }
        }

        // Main temperature + icon
        CutShape {
            Layout.fillWidth: true
            implicitHeight: bigRow.implicitHeight + 12
            visible: !root.loading && !root.hasError
            fillColor: Colours.moduleBg
            strokeColor: Colours.neonBorder(0.25)
            strokeWidth: 1
            inset: 0.5
            cutTopRight: 8

            RowLayout {
                id: bigRow
                anchors.centerIn: parent
                spacing: 12

                Text {
                    text: root.weatherIcon
                    font.pixelSize: 36
                    color: Colours.accentSecondary
                }

                Column {
                    spacing: -2
                    Text {
                        text: root.tempStr
                        font.family: "Oxanium"
                        font.pixelSize: 28
                        font.weight: Font.Bold
                        color: Colours.accentPrimary
                    }
                    Text {
                        text: root.condition
                        font.family: "Oxanium"
                        font.pixelSize: 10
                        color: Colours.textSecondary
                    }
                }
            }
        }

        // Detail cards: humidity / feels like / wind
        RowLayout {
            Layout.fillWidth: true
            visible: !root.loading && !root.hasError
            spacing: 4

            DetailCard { icon: "💧"; label: "Humidity";   value: root.humidity;  colour: Colours.accentSecondary }
            DetailCard { icon: "🌡";  label: "Feels Like"; value: root.feelsLike; colour: Colours.accentPrimary }
            DetailCard { icon: "💨"; label: "Wind";       value: root.windSpeed; colour: CP.magenta }
        }

        // Forecast title
        Text {
            Layout.topMargin: 2
            visible: !root.loading && !root.hasError && root.forecast.length > 0
            text: "5-Day Forecast"
            font.family: "Oxanium"
            font.pixelSize: 10
            font.weight: Font.Bold
            color: Colours.textPrimary
        }

        // Forecast cards
        RowLayout {
            Layout.fillWidth: true
            visible: !root.loading && !root.hasError
            spacing: 4

            Repeater {
                model: root.forecast

                CutShape {
                    id: forecastItem
                    Layout.fillWidth: true
                    implicitHeight: fcCol.implicitHeight + 10
                    fillColor: Colours.moduleBg
                    strokeColor: Colours.neonBorder(0.2)
                    strokeWidth: 1
                    inset: 0.5
                    cutTopRight: 6

                    required property int index
                    required property var modelData

                    Column {
                        id: fcCol
                        anchors.centerIn: parent
                        spacing: 3

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: forecastItem.index === 0 ? "Today" : forecastItem.modelData.date.toLocaleDateString(Qt.locale(), "ddd")
                            font.family: "Oxanium"
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            color: Colours.accentPrimary
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: forecastItem.modelData.icon
                            font.pixelSize: 14
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: forecastItem.modelData.maxC + " / " + forecastItem.modelData.minC
                            font.family: "Oxanium"
                            font.pixelSize: 9
                            font.weight: Font.Medium
                            color: Colours.accentSecondary
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    // -- Inline components --

    component DetailCard: CutShape {
        id: detailRoot
        Layout.fillWidth: true
        implicitHeight: 50        
        fillColor: Colours.moduleBg
        strokeColor: Colours.neonBorder(0.2)
        strokeWidth: 1
        inset: 0.5
        cutBottomLeft: 6

        property string label
        property string value
        property string icon
        property color colour

        Row {
            anchors.centerIn: parent
            spacing: 6

            Text { text: detailRoot.icon; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    text: detailRoot.label
                    font.family: "Oxanium"
                    font.pixelSize: 8
                    color: Colours.textSecondary
                }
                Text {
                    text: detailRoot.value
                    font.family: "Oxanium"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: detailRoot.colour
                }
            }
        }
    }

    component WeatherStat: Row {
        id: ws
        property string icon
        property string label
        property string value
        property color colour
        spacing: 4

        Text { text: ws.icon; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
        Column {
            Text { text: ws.label; font.family: "Oxanium"; font.pixelSize: 8; color: Colours.textSecondary }
            Text { text: ws.value; font.family: "Oxanium"; font.pixelSize: 10; font.weight: Font.Bold; color: ws.colour }
        }
    }
}

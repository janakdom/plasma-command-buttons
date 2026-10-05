import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// Dlaždice: ikona nahoře, popisek pod ní. Během běhu točí kolečko,
// po doběhnutí krátce ukáže výsledek (fajfka / křížek).
PlasmaComponents3.Button {
    id: tile

    property string iconName
    property string command
    // text při najetí myší ("" = žádný tooltip)
    property string tooltipText: command
    property bool busy: false
    // "", "ok" nebo "error"
    property string status: ""
    // označeno klávesnicí (šipkami)
    property bool selected: false

    // fokus zůstává na widgetu, aby šipky fungovaly i po kliknutí myší
    focusPolicy: Qt.NoFocus

    implicitHeight: Kirigami.Units.gridUnit * 3.5
    // během běhu nezešedne (kolečko by bylo bledé); opakované spuštění hlídá main.qml
    enabled: command.length > 0

    PlasmaComponents3.ToolTip.text: tooltipText
    PlasmaComponents3.ToolTip.visible: hovered && tooltipText.length > 0
    PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay

    Rectangle {
        anchors.fill: parent
        visible: tile.selected
        radius: Kirigami.Units.cornerRadius
        color: Qt.alpha(Kirigami.Theme.highlightColor, 0.15)
        border.width: 2
        border.color: Kirigami.Theme.highlightColor
    }

    // bez názvu jen větší ikona, vycentrovaná i na výšku
    readonly property bool iconOnly: text.length === 0
    readonly property int iconSize: iconOnly ? Math.round(Kirigami.Units.iconSizes.medium * 1.25) : Kirigami.Units.iconSizes.medium

    Accessible.name: text.length > 0 ? text : command

    contentItem: Item {
        implicitWidth: column.implicitWidth
        implicitHeight: column.implicitHeight

        ColumnLayout {
            id: column
            anchors.centerIn: parent
            width: parent.width
            spacing: Kirigami.Units.smallSpacing

            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: tile.iconSize
                implicitHeight: tile.iconSize

                Kirigami.Icon {
                    anchors.fill: parent
                    source: tile.iconName || "system-run"
                    // jinak by se 40 px zaokrouhlilo dolů na standardních 32 px
                    roundToIconSize: false
                    visible: tile.status === ""
                    opacity: tile.busy ? 0 : 1
                    Behavior on opacity {
                        NumberAnimation { duration: Kirigami.Units.shortDuration }
                    }
                }

                // výsledek: tučná fajfka / křížek (ikony z motivu jsou na to moc tenké)
                Shape {
                    id: mark
                    anchors.fill: parent
                    visible: tile.status !== ""
                    preferredRendererType: Shape.CurveRenderer

                    readonly property real s: width
                    readonly property color markColor: tile.status === "ok"
                        ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor

                    ShapePath {
                        strokeColor: mark.markColor
                        strokeWidth: mark.s * 0.14
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        PathPolyline {
                            path: tile.status === "ok"
                                ? [Qt.point(mark.s * 0.18, mark.s * 0.54), Qt.point(mark.s * 0.41, mark.s * 0.76), Qt.point(mark.s * 0.84, mark.s * 0.28)]
                                : [Qt.point(mark.s * 0.24, mark.s * 0.24), Qt.point(mark.s * 0.76, mark.s * 0.76)]
                        }
                    }
                    ShapePath {
                        strokeColor: tile.status === "error" ? mark.markColor : "transparent"
                        strokeWidth: mark.s * 0.14
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathPolyline {
                            path: [Qt.point(mark.s * 0.76, mark.s * 0.24), Qt.point(mark.s * 0.24, mark.s * 0.76)]
                        }
                    }
                }

                // běží: tlusté točící se kolečko, stejně silné jako fajfka
                Shape {
                    id: spinner
                    anchors.fill: parent
                    visible: tile.busy
                    preferredRendererType: Shape.CurveRenderer

                    readonly property real s: width

                    ShapePath {
                        strokeColor: Kirigami.Theme.highlightColor
                        strokeWidth: spinner.s * 0.14
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: spinner.s / 2
                            centerY: spinner.s / 2
                            radiusX: spinner.s * 0.36
                            radiusY: spinner.s * 0.36
                            startAngle: 0
                            sweepAngle: 270
                        }
                    }

                    RotationAnimator on rotation {
                        running: spinner.visible
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                    }
                }
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                visible: !tile.iconOnly
                horizontalAlignment: Text.AlignHCenter
                textFormat: Text.PlainText
                elide: Text.ElideRight
                text: tile.text
            }
        }
    }
}

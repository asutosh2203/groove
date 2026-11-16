pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import ".."

Item {
    id: maskedArtwork

    property var artworkSource: ""
    property real cornerRadius: height / 2
    property string mode: "idle"
    property string kind: "music"
    property real progress: 0
    property bool playing: false
    property real glyphSize: width * 0.74
    readonly property bool hasArtworkSource: artworkSource && artworkSource.toString().length > 0
    readonly property bool hasArtwork: hasArtworkSource && maskedImage.status === Image.Ready

    Rectangle {
        anchors.fill: parent
        radius: maskedArtwork.cornerRadius
        color: "#101015"
    }

    Image {
        id: maskedImage

        anchors.fill: parent
        source: maskedArtwork.hasArtworkSource ? maskedArtwork.artworkSource : ""
        fillMode: Image.PreserveAspectCrop
        visible: maskedArtwork.hasArtwork
        layer.enabled: visible

        layer.effect: MultiEffect {
            maskEnabled: true
            maskSpreadAtMax: 1
            maskSpreadAtMin: 1
            maskThresholdMin: 0.5

            maskSource: ShaderEffectSource {

                sourceItem: Rectangle {
                    width: maskedImage.width
                    height: maskedImage.height
                    radius: maskedArtwork.cornerRadius
                    color: "#ffffff"
                }

            }

        }

    }

    MediaPlaceholder {
        anchors.fill: parent
        kind: maskedArtwork.kind
        cornerRadius: maskedArtwork.cornerRadius
        visible: maskedArtwork.mode === "media" && !maskedArtwork.hasArtwork
    }

    IslandGlyph {
        anchors.centerIn: parent
        width: maskedArtwork.glyphSize
        height: width
        mode: maskedArtwork.mode
        progress: maskedArtwork.progress
        playing: maskedArtwork.playing
        visible: maskedArtwork.mode !== "media" && !maskedArtwork.hasArtwork
    }

}

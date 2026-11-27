import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Plain by default: labels show outside text (notifications, track names, file and device names), and AutoText would turn
// a tag in it into rich text that loads remote images. A label that needs markup sets its textFormat explicitly.
QQC2.Label {
    textFormat: Text.PlainText
    font.family: Kirigami.Theme.defaultFont.family
    font.styleName: ""
}

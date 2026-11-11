import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: configPage

    property string cfg_shellShape
    property string cfg_weatherLocationName
    property real cfg_weatherLatitude
    property real cfg_weatherLongitude
    property string cfg_weatherUnit
    property string cfg_calendarApp
    property var locationResults: []
    property string locationStatus: ""

    // Open-Meteo geocoding: the user searches and explicitly picks a result (no GPS/IP guessing).
    function searchLocation(query) {
        const name = query.trim();
        if (name.length < 2) {
            locationStatus = i18n("Type at least two characters.");
            return ;
        }
        locationStatus = i18n("Searching…");
        locationResults = [];
        const request = new XMLHttpRequest();
        request.timeout = 15000;
        request.onreadystatechange = () => {
            if (request.readyState !== XMLHttpRequest.DONE)
                return ;
            try {
                const rows = request.status === 200 ? (JSON.parse(request.responseText).results || []) : null;
                if (rows === null) {
                    locationStatus = i18n("Search failed. Check your connection and try again.");
                    return ;
                }
                locationResults = rows.map(r => ({
                    "text": [r.name, r.admin1, r.country].filter(x => x && x.length > 0).join(", "),
                    "name": r.name,
                    "lat": r.latitude,
                    "lon": r.longitude
                }));
                locationStatus = rows.length === 0 ? i18n("No matching places found.") : i18np("%1 match. Choose one below.", "%1 matches. Choose one below.", rows.length);
            } catch (e) {
                locationStatus = i18n("Search failed. Check your connection and try again.");
            }
        };
        request.ontimeout = () => { locationStatus = i18n("Search timed out."); };
        request.onerror = () => { locationStatus = i18n("Search failed. Check your connection and try again."); };
        request.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=8&format=json&language=" + encodeURIComponent(Qt.locale().name.split("_")[0]) + "&name=" + encodeURIComponent(name));
        request.send();
    }
    property alias cfg_mediaActivityEnabled: mediaActivityEnabled.checked
    property alias cfg_notificationActivityEnabled: notificationActivityEnabled.checked
    property alias cfg_jobActivityEnabled: jobActivityEnabled.checked
    property alias cfg_keyboardLayoutActivityEnabled: keyboardLayoutActivityEnabled.checked
    property alias cfg_notificationShowImages: notificationShowImages.checked
    property alias cfg_notificationBodyCharacterLimit: notificationBodyCharacterLimit.value
    property alias cfg_notificationBodyLineLimit: notificationBodyLineLimit.value
    property alias cfg_notificationPopupDurationSeconds: notificationPopupDurationSeconds.value
    property alias cfg_ongoingPopupDurationSeconds: ongoingPopupDurationSeconds.value

    Kirigami.FormLayout {
        QQC2.ComboBox {
            id: shellShape

            Kirigami.FormData.label: i18n("Appearance:")
            textRole: "text"
            valueRole: "value"
            model: [
                { "text": i18n("Dynamic Pill"), "value": "pill" },
                { "text": i18n("Dynamic Notch"), "value": "notch" }
            ]
            currentIndex: Math.max(0, indexOfValue(configPage.cfg_shellShape))
            onActivated: configPage.cfg_shellShape = currentValue
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Idle display")
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Weather location:")
            text: configPage.cfg_weatherLocationName.length > 0 ? configPage.cfg_weatherLocationName + "  (" + configPage.cfg_weatherLatitude.toFixed(2) + ", " + configPage.cfg_weatherLongitude.toFixed(2) + ")" : i18n("Not set")
            opacity: configPage.cfg_weatherLocationName.length > 0 ? 1 : 0.6
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Search city:")

            QQC2.TextField {
                id: locationQuery

                Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                placeholderText: i18n("City name")
                onAccepted: configPage.searchLocation(text)
            }

            QQC2.Button {
                text: i18n("Search")
                icon.name: "edit-find"
                onClicked: configPage.searchLocation(locationQuery.text)
            }
        }

        QQC2.ComboBox {
            id: locationPicker

            Kirigami.FormData.label: i18n("Matches:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
            enabled: configPage.locationResults.length > 0
            model: configPage.locationResults
            textRole: "text"
            currentIndex: -1
            displayText: currentIndex < 0 ? i18n("Choose a match…") : currentText
            // A fresh result list must not pre-select its first row: the user picks explicitly.
            onCountChanged: Qt.callLater(() => { currentIndex = -1; })
            onActivated: index => {
                const r = configPage.locationResults[index];
                configPage.cfg_weatherLocationName = r.text;
                configPage.cfg_weatherLatitude = r.lat;
                configPage.cfg_weatherLongitude = r.lon;
            }
        }

        QQC2.Label {
            visible: configPage.locationStatus.length > 0
            text: configPage.locationStatus
            opacity: 0.7
        }

        QQC2.ComboBox {
            id: weatherUnit

            Kirigami.FormData.label: i18n("Temperature:")
            textRole: "text"
            valueRole: "value"
            model: [
                { "text": i18n("Celsius (°C)"), "value": "celsius" },
                { "text": i18n("Fahrenheit (°F)"), "value": "fahrenheit" }
            ]
            currentIndex: Math.max(0, indexOfValue(configPage.cfg_weatherUnit))
            onActivated: configPage.cfg_weatherUnit = currentValue
        }

        QQC2.TextField {
            Kirigami.FormData.label: i18n("Calendar application:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
            placeholderText: i18n("Desktop file ID, e.g. org.kde.korganizer (empty: system default)")
            text: configPage.cfg_calendarApp
            onTextEdited: configPage.cfg_calendarApp = text
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Weather data:")
            text: i18n("<a href=\"https://open-meteo.com/\">Weather data by Open-Meteo.com</a> (CC BY 4.0)")
            textFormat: Text.StyledText
            onLinkActivated: link => Qt.openUrlExternally(link)
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
        }

        PlasmaCheckBox {
            id: mediaActivityEnabled

            Kirigami.FormData.label: i18n("Activity providers:")
            text: i18n("Music playback")
        }

        PlasmaCheckBox {
            id: notificationActivityEnabled

            text: i18n("Notifications")
        }

        PlasmaCheckBox {
            id: jobActivityEnabled

            text: i18n("Downloads and jobs")
        }

        PlasmaCheckBox {
            id: keyboardLayoutActivityEnabled

            text: i18n("Keyboard layout announcements")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
        }

        PlasmaCheckBox {
            id: notificationShowImages

            Kirigami.FormData.label: i18n("Notifications:")
            text: i18n("Show images and thumbnails")
        }

        PlasmaSpinBox {
            id: notificationBodyCharacterLimit

            Kirigami.FormData.label: i18n("Body length:")
            from: 40
            to: 1000
            stepSize: 20
            editable: true
            textFromValue: (value, locale) => i18np("%1 character", "%1 characters", value)
            valueFromText: (text, locale) => {
                const parsed = parseInt(text);
                return isFinite(parsed) ? Math.max(from, Math.min(to, parsed)) : from;
            }
        }

        PlasmaSpinBox {
            id: notificationBodyLineLimit

            Kirigami.FormData.label: i18n("Preview lines:")
            from: 1
            to: 6
            editable: true
        }

        PlasmaSpinBox {
            id: notificationPopupDurationSeconds

            Kirigami.FormData.label: i18n("Popup duration:")
            from: 2
            to: 15
            textFromValue: (value, locale) => i18np("%1 second", "%1 seconds", value)
            valueFromText: (text, locale) => {
                const parsed = parseInt(text);
                return isFinite(parsed) ? Math.max(from, Math.min(to, parsed)) : from;
            }
        }

        PlasmaSpinBox {
            id: ongoingPopupDurationSeconds

            Kirigami.FormData.label: i18n("Other announcements:")
            from: 2
            to: 15
            textFromValue: (value, locale) => i18np("%1 second", "%1 seconds", value)
            valueFromText: (text, locale) => {
                const parsed = parseInt(text);
                return isFinite(parsed) ? Math.max(from, Math.min(to, parsed)) : from;
            }
        }
    }
}

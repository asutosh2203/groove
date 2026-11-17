pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.private.digitalclock as DigitalClock

// Plasma's own time zone data, the same the stock clock's settings use (D-56): every IANA zone with its translated city and
// region, filtered by what the user types. A private plasma-workspace module, so it is loaded on its own: when it is
// missing TimezoneField falls back to a plain id entry. Recheck on Plasma upgrades.
Item {
    id: search

    property string query: ""
    readonly property var zones: filter

    function cityOf(id) {
        return DigitalClock.TimeZonesI18n.i18nCity(id);
    }

    DigitalClock.TimeZoneModel {
        id: model
    }

    DigitalClock.TimeZoneFilterProxy {
        id: filter

        sourceModel: model
        filterString: search.query
    }
}

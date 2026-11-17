pragma ComponentBehavior: Bound

import QtQuick
import "../logic/WeatherForecast.js" as Forecast
import "../weather"

// The weather services for widget placements (D-55). A placement with location "island" (or the same coordinates) gets the
// idle face's own service, so no location is fetched or cached twice; every other distinct location gets one shared
// service. The services are created from the presets, not on demand, and work only while a view subscribes.
Item {
    id: hub

    // The idle face's service.
    required property var island
    // Locations used by the presets other than "island": [{ name, lat, lon }].
    required property var locations
    // Bumped when a service appears or goes, so serviceFor re-evaluates in a binding.
    property int revision: 0
    readonly property var unique: Forecast.uniqueLocations(hub.locations, Forecast.locationKey(hub.island.latitude, hub.island.longitude))

    // The shared service for a placement's location setting, or null while it is being created.
    function serviceFor(location) {
        hub.revision;
        if (location === "island" || !location)
            return hub.island;
        const key = Forecast.locationKey(location.lat, location.lon);
        if (key === Forecast.locationKey(hub.island.latitude, hub.island.longitude))
            return hub.island;
        for (let i = 0; i < services.count; ++i) {
            const service = services.objectAt(i) as WeatherService;
            if (service && Forecast.locationKey(service.latitude, service.longitude) === key)
                return service;
        }
        return null;
    }

    Instantiator {
        id: services

        model: hub.unique
        onObjectAdded: hub.revision++
        onObjectRemoved: hub.revision++

        delegate: WeatherService {
            required property var modelData

            followsSettings: false
            locationName: modelData.name
            latitude: modelData.lat
            longitude: modelData.lon
        }
    }
}

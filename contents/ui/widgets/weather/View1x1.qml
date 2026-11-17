pragma ComponentBehavior: Bound

// Weather 1x1 (D-55): the left block alone.
WeatherBase {
    LeftBlock {
        anchors.fill: parent
        base: parent as WeatherBase
    }
}

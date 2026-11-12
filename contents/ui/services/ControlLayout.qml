pragma ComponentBehavior: Bound

import QtQuick
import "../logic/ControlLayout.js" as Logic
import "../logic/ModuleRegistry.js" as ModuleRegistry
import "../logic/Utils.js" as Utils

// The Control Center layout: the stored layout, the edit session (draft, dirty, save, cancel, reset), and the drag and
// resize state the editor and the module cards share. The rules themselves are pure (logic/ControlLayout.js). The owner
// of the widget config persists what saveRequested asks for; this object never touches the config.
QtObject {
    id: service

    // The layout as stored in the widget config (JSON). Empty means "never saved".
    required property string storedJson
    // The item drag positions are mapped into (the popup content host).
    property Item dragHost: null
    // What the module icons depend on: { wifiEnabled, batteryCharging, powerProfileIcon }.
    property var iconState: ({})

    signal saveRequested(string json)

    property bool editMode: false
    property int revision: 0
    property var draft: []
    property bool dragActive: false
    property var dragSource: null
    property string dragIcon: ""
    property real dragX: 0
    property real dragY: 0
    property int dragSize: 54
    property int dragOffsetCol: 0
    property int dragOffsetRow: 0
    // The editor page currently showing, so a drag started on a card can preview and drop into it.
    property var activePage: null
    property int dropCol: -1
    property int dropRow: -1
    property bool dropOnPalette: false
    property bool dropInvalid: false
    property bool resizeActive: false
    property var resizeSource: null
    property int resizeIndex: -1
    property int resizeWidthUnits: 1
    property int resizeHeightUnits: 1
    readonly property var modules: ModuleRegistry.allModules()
    readonly property bool dirty: editMode && revision >= 0 && !Logic.sameLayout(draft, committedLayout())

    onEditModeChanged: {
        if (!editMode)
            resetInteraction();

    }

    function resetInteraction() {
        dragActive = false;
        resizeActive = false;
        dropCol = -1;
        dropRow = -1;
        dropOnPalette = false;
        dropInvalid = false;
        dragSource = null;
        dragOffsetCol = 0;
        dragOffsetRow = 0;
        resizeSource = null;
        resizeIndex = -1;
        resizeWidthUnits = 1;
        resizeHeightUnits = 1;
    }

    function defaultLayout() {
        return ModuleRegistry.defaultLayout();
    }

    function minSize(id) {
        return ModuleRegistry.minSize(id);
    }

    function maxSize(id) {
        return ModuleRegistry.maxSize(id);
    }

    function defaultSize(id) {
        return ModuleRegistry.defaultSize(id);
    }

    function clampedModule(id, widthUnits, heightUnits) {
        return Logic.clampedModule(id, widthUnits, heightUnits);
    }

    function committedLayout() {
        return Logic.committed(storedJson);
    }

    // The layout being shown: the draft while editing, the stored one otherwise.
    function currentLayout() {
        if (revision < 0) // never true: reading it re-evaluates callers whenever the layout changes
            return [];

        if (editMode && Array.isArray(draft))
            return Logic.sanitize(draft);

        return committedLayout();
    }

    function saveLayout(layout) {
        saveRequested(JSON.stringify(Logic.sanitize(layout)));
        revision++;
    }

    function updateLayout(layout) {
        if (editMode) {
            draft = Logic.sanitize(layout);
            revision++;
        } else {
            saveLayout(layout);
        }
    }

    function ensureLayout() {
        if (!storedJson || storedJson.length === 0)
            saveLayout(defaultLayout());

    }

    function beginEdit() {
        draft = committedLayout();
        editMode = true;
        revision++;
    }

    function saveEdit() {
        if (!editMode)
            return ;

        if (dirty)
            saveLayout(draft);

        draft = [];
        editMode = false;
    }

    function cancelEdit() {
        if (!editMode)
            return ;

        draft = [];
        editMode = false;
        revision++;
    }

    function resetLayout() {
        updateLayout(defaultLayout());
    }

    function removeModule(index) {
        const layout = Logic.removeModule(currentLayout(), index);
        if (layout)
            updateLayout(layout);

    }

    function addModule(id) {
        insertModule(id, -1);
    }

    function insertModule(id, target) {
        const layout = Logic.insertModule(currentLayout(), id, target);
        if (layout)
            updateLayout(layout);

    }

    function moduleInfo(id) {
        return ModuleRegistry.info(id);
    }

    function moduleIcon(id) {
        return ModuleRegistry.icon(id, iconState);
    }

    function beginDrag(source, item, mouse, size) {
        if (!editMode || !dragHost || !source || !item || !mouse || !item.mapToItem)
            return ;

        const pos = item.mapToItem(dragHost, mouse.x, mouse.y);
        dragSource = source;
        dragIcon = moduleIcon(source.moduleId);
        dragSize = Math.max(32, Math.min(96, Utils.finiteNumber(size, 54)));
        dragX = pos.x - dragSize / 2;
        dragY = pos.y - dragSize / 2;
        dragActive = true;
    }

    function updateDrag(item, mouse) {
        if (!dragActive || !dragHost || !item || !mouse || !item.mapToItem)
            return ;

        const pos = item.mapToItem(dragHost, mouse.x, mouse.y);
        dragX = pos.x - dragSize / 2;
        dragY = pos.y - dragSize / 2;
        if (activePage)
            activePage.previewControlDrop(pos.x, pos.y);

    }

    function endDrag(item, mouse, commit) {
        if (commit && dragActive && activePage && dragHost && item && mouse && item.mapToItem) {
            const pos = item.mapToItem(dragHost, mouse.x, mouse.y);
            activePage.finishControlDrop(dragSource, pos.x, pos.y);
        }

        dragActive = false;
        dropCol = -1;
        dropRow = -1;
        dropOnPalette = false;
        dragOffsetCol = 0;
        dragOffsetRow = 0;
        Qt.callLater(function() {
            if (!service.dragActive)
                service.dragSource = null;

        });
    }

    function beginResize(source) {
        if (!editMode || !source || !activePage)
            return ;

        if (source.moduleIndex < 0)
            return ;

        resizeSource = source;
        resizeIndex = source.moduleIndex;
        resizeWidthUnits = source.moduleWidthUnits;
        resizeHeightUnits = source.moduleHeightUnits;
        resizeActive = true;
    }

    function updateResize(source, widthUnits, heightUnits) {
        if (!resizeActive || !source || source !== resizeSource)
            return ;

        const size = clampedModule(source.moduleId, widthUnits, heightUnits);
        resizeWidthUnits = size.w;
        resizeHeightUnits = size.h;
    }

    function endResize(source, commit) {
        if (commit && resizeActive && activePage && source && source === resizeSource)
            activePage.commitControlResize(source, resizeWidthUnits, resizeHeightUnits);

        resizeActive = false;
        resizeSource = null;
        resizeIndex = -1;
        resizeWidthUnits = 1;
        resizeHeightUnits = 1;
    }
}

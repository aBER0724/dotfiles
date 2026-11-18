import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell.Services.SystemTray
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "TrayModel.js" as TrayModel

BarWidget {
  id: root
  moduleName: "aber.tray"

  // Drawer depth: 0 closed, 1 the regular icons (single click), 2 also the
  // always-hidden ones (double click).
  property int drawerLevel: 0
  property real lastChevronPress: 0
  property bool managePopupOpen: false
  property bool trayMenuOpen: false
  property var activeTrayItem: null
  property var activeTrayAnchor: null
  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var pinnedIds: settings.pinned instanceof Array ? settings.pinned : []
  readonly property var hiddenIds: settings.hidden instanceof Array ? settings.hidden : []
  readonly property var pinnedItems: bucket("pinned")
  // Level 1 shows the regular drawer icons; level 2, reached by double-
  // clicking the blank bar, appends the always-hidden ones.
  readonly property var drawerItems: {
    var items = bucket("drawer")
    if (drawerLevel >= 2) {
      var buried = bucket("alwaysHidden")
      for (var i = 0; i < buried.length; i++) items.push(buried[i])
    }
    return items
  }
  readonly property var allItems: bucket("all")
  readonly property int drawerCount: drawerItems.length
  readonly property int trayItemExtent: Style.bar.iconSlot
  readonly property int trayItemGap: 0
  readonly property int trayJoinGap: 0
  // Bar widgets dragged into the tray section sit in the drawer after the
  // app icons. The bar draws them into sectionHost, and outlines it while a
  // widget is dragged, as it does the center box.
  property Item sectionHost: null
  // The part of the tray section the drawer shows, in the tray ({ x, y,
  // width, height }), or null while it shows none of it. It moves with the
  // drawer's contents as they slide in and out, and is cut to the drawer as
  // they are, so the bar's outline of it never reaches past the tray.
  readonly property var sectionShown: trayContent.item ? trayContent.item.sectionShown : null
  readonly property int sectionCount: bar && bar.layoutConfig && Array.isArray(bar.layoutConfig.tray) ? bar.layoutConfig.tray.length : 0
  readonly property real sectionExtent: sectionHost ? (vertical ? sectionHost.implicitHeight : sectionHost.implicitWidth) : 0
  readonly property bool hasDrawer: allItems.length > 0 || sectionCount > 0 || barDragging
  readonly property int drawerExtent: drawerCount * trayItemExtent + Math.max(0, drawerCount - 1) * trayItemGap + sectionExtent
  // The extent the drawer is drawn at. It trails drawerExtent so that going
  // from level 1 to level 2 (the always-hidden icons appearing) grows the
  // drawer instead of snapping it wider in a single frame.
  property real drawerExtentSmooth: 0
  onDrawerExtentChanged: drawerExtentSmooth = drawerExtent
  // The bar reports a drag in progress for any widget on any bar, not only for
  // one of the drawer's own.
  readonly property bool barDragging: !!bar && bar.traySectionDragActive === true
  // A drag holds the drawer open only when it started with the drawer open,
  // which is the one case that needs it: pulling a widget out of the drawer.
  // A drag that starts on the bar itself must not open the drawer -- doing so
  // shifts the whole right section out from under the pointer, so the widget
  // being dragged jumps away and the drop lands somewhere else. `barDragging`
  // is the bar's `traySectionDragActive`, which is true for *any* widget being
  // dragged, not just one from the drawer.
  readonly property bool holdOpen: trayMenuOpen || managePopupOpen
    || (barDragging && drawerLevel > 0)
    || (!!bar && bar.traySectionPopoutOpen === true)
  // The mark under the bar sits under the icon whose menu is open.
  readonly property Item openPanelIndicatorItem: trayMenuOpen ? activeTrayAnchor : null
  // The drawer's slide, in ms. Deliberately a fixed duration rather than
  // Style.duration(): Omarchy zeroes every shell animation on a machine that
  // renders on the CPU (this VM draws with llvmpipe, and
  // ~/.local/state/omarchy/toggles/hypr/no-animations.lua turns animations
  // off), which left the drawer snapping open with nothing to show the blank
  // click had landed. A slide this small costs nothing to draw, so it keeps
  // its motion either way.
  readonly property int animationDuration: 300
  // Behaviour does not animate a value that comes from a binding, so the
  // drawer's progress is assigned rather than bound: syncReveal() writes the
  // 0 or 1 the state asks for and the Behaviour eases from wherever it is.
  property real revealProgress: 0
  readonly property real revealExtent: drawerExtentSmooth * revealProgress

  function syncReveal() {
    revealProgress = (drawerLevel > 0 || holdOpen) ? 1 : 0
  }
  onHoldOpenChanged: syncReveal()
  Component.onCompleted: {
    drawerExtentSmooth = drawerExtent
    syncReveal()
    refreshTierRows()
  }
  // The pinned icons sit against the tray's fixed edge, the drawer opening
  // between them and pushing them out of the way, while the pointer that
  // opened it stays over the drawer. A centered tray keeps the end-fixed
  // arrangement.
  readonly property bool fixedAtStart: fixedEdge === "start"
  // The edge the tray section's widgets grow from: the one the pinned icons
  // keep to, beside which the section opens.
  readonly property string sectionEdge: fixedAtStart ? "start" : "end"

  // Submenu drill-down state. QsMenuEntry.display() renders a *platform* menu,
  // which Quickshell refuses unless the shell root sets `//@ pragma
  // UseQApplication` - omarchy's shell.qml does not, so every submenu click was
  // a silent no-op ("Cannot display PlatformMenuEntry as quickshell was not
  // started in QApplication mode" in the shell log) and apps whose whole UI is
  // submenus, e.g. radiotray-ng's station list, were unusable. QsMenuEntry
  // inherits QsMenuHandle, so a child entry can feed a nested QsMenuOpener and
  // render inside this popup instead of going through the platform. Each level
  // keeps its own live opener: a child entry is owned by its parent opener's
  // model, so collapsing the stack to a single opener would destroy the very
  // entry being displayed (submenu turns up empty).
  property var submenuStack: []
  readonly property int submenuDepth: submenuStack.length
  readonly property string currentTitle: submenuDepth > 0 ? submenuStack[submenuDepth - 1].title : ""
  readonly property var currentChildren: submenuDepth > 0
    ? submenuStack[submenuDepth - 1].opener.children
    : trayMenuOpener.children

  // Changing level rebuilds the row delegates synchronously, so the next
  // row lands under a cursor that hasn't moved. Submenu clicks used to be
  // silent no-ops, which trained users to click them twice, and that second
  // click would now fire whatever entry took the spot. Ignore row clicks for
  // a beat after each level change; a deliberate follow-up click is slower.
  property bool menuLevelSettling: false

  Component {
    id: submenuOpenerComponent
    QsMenuOpener {}
  }

  Timer {
    id: menuLevelSettleTimer
    interval: 250
    onTriggered: root.menuLevelSettling = false
  }

  function settleMenuLevel() {
    menuLevelSettling = true
    menuLevelSettleTimer.restart()
  }

  function resetTrayMenu() {
    menuLevelSettling = false
    menuLevelSettleTimer.stop()
    // Flickable keeps its offset across a model swap whenever the new content
    // is still tall enough to hold it, so a menu dismissed while scrolled
    // would otherwise reopen part-way down with its first entries off screen.
    trayMenuFlick.contentY = 0
    // Clear the reactive stack before tearing anything down, so no binding can
    // read a partially-destroyed opener while this runs. Then destroy deepest
    // first: an inner opener's menu entry is owned by its parent's children
    // model, so destroying a parent first would invalidate an entry a still-
    // live child opener references.
    var openers = submenuStack
    submenuStack = []
    for (var i = openers.length - 1; i >= 0; i--) openers[i].opener.destroy()
  }

  function enterSubmenu(entry, title) {
    var opener = submenuOpenerComponent.createObject(root, { menu: entry })
    if (!opener) return
    var stack = submenuStack.slice()
    stack.push({ opener: opener, title: title })
    submenuStack = stack
    settleMenuLevel()
  }

  function leaveSubmenu() {
    if (submenuStack.length === 0) return
    var stack = submenuStack.slice()
    var top = stack.pop()
    submenuStack = stack
    top.opener.destroy()
    settleMenuLevel()
  }

  function close() {
    managePopupOpen = false
    trayMenuOpen = false
  }

  function openTrayMenu(item, anchorItem, mouse) {
    if (!item) return

    // Apps that draw their own context menu (Windows apps under Wine) publish
    // no D-Bus menu, and Quickshell can only show D-Bus menus. Ask the app
    // for its menu instead.
    if (!item.hasMenu) {
      Util.execArgv(["omarchy-tray-context-menu", item.id])
      return
    }

    if (!item.menu) {
      var point = anchorItem.QsWindow.contentItem.mapFromItem(anchorItem, mouse.x, mouse.y)
      item.display(anchorItem.QsWindow.window, point.x, point.y)
      return
    }

    // Reset before switching items: trayMenuOpener.menu binds to
    // activeTrayItem.menu, so assigning a new item invalidates the old root's
    // children immediately, before any nested opener referencing them would
    // otherwise get torn down.
    resetTrayMenu()
    activeTrayItem = item
    activeTrayAnchor = anchorItem
    trayMenuOpen = true
  }

  function trayIconSource(icon) {
    // Quickshell already resolves the tray icon into a ready-to-use image://
    // URL, including a "?path=" fallback search dir for apps that ship their
    // tray icon outside a standard theme (e.g. Steam's flat public/ dir). Hand
    // it straight to IconImage; guessing a theme sub-directory here only broke
    // apps whose layout didn't match the guess.
    return String(icon || "")
  }

  // Symbolic icons ship a fixed fill (light or dark) that the host is meant
  // to recolor to its foreground; detect them by the freedesktop "-symbolic"
  // name suffix so they can be tinted instead of rendered as-is.
  function iconIsSymbolic(icon) {
    var name = String(icon || "").split("?")[0]
    return name.slice(-9) === "-symbolic"
  }

  function trayTooltip(item) {
    return item.tooltipTitle || item.title || item.id || ""
  }

  // Three tiers: pinned icons stay on the bar; everything unlisted shows in
  // the drawer on a single click; the `hidden` list only comes out on the
  // double-clicked drawer (the manage popup's "hide" button).
  function classifyItem(item) {
    var iid = String(item.id || "")
    if (hiddenIds.indexOf(iid) !== -1) return "alwaysHidden"
    if (pinnedIds.indexOf(iid) !== -1) return "pinned"
    return "drawer"
  }

  function ownedByOmarchy(item) {
    var layout = root.bar && root.bar.layoutConfig ? root.bar.layoutConfig : null
    return TrayModel.ownedByOmarchy(item, layout)
  }

  function bucket(category) {
    var values = SystemTray.items.values
    var result = []
    for (var i = 0; i < values.length; i++) {
      var item = values[i]
      if (item.status === Status.Passive) continue
      if (ownedByOmarchy(item)) continue
      if (category === "all") {
        result.push(item)
        continue
      }
      if (classifyItem(item) === category) result.push(item)
    }
    return result
  }

  function persistTrayState(pinned, hidden) {
    if (!root.bar || !root.bar.shell || typeof root.bar.shell.updateEntryInline !== "function") return
    var id = root.moduleName || "omarchy.tray"
    root.bar.shell.updateEntryInline(id, { id: id, pinned: pinned, hidden: hidden })
  }

  function togglePin(iid) {
    var p = pinnedIds.slice(), h = hiddenIds.slice()
    var idx = p.indexOf(iid)
    if (idx !== -1) p.splice(idx, 1)
    else {
      p.push(iid)
      var hi = h.indexOf(iid)
      if (hi !== -1) h.splice(hi, 1)
    }
    persistTrayState(p, h)
  }

  function toggleHide(iid) {
    var p = pinnedIds.slice(), h = hiddenIds.slice()
    var idx = h.indexOf(iid)
    if (idx !== -1) h.splice(idx, 1)
    else {
      h.push(iid)
      var pi = p.indexOf(iid)
      if (pi !== -1) p.splice(pi, 1)
    }
    persistTrayState(p, h)
  }

  // A left click on the bar's blank middle: a press opens the drawer one
  // level, a second press inside the double-click window escalates it to also
  // reveal the always-hidden icons, and a press while open closes it again.
  // The first press of a double-click already opened level 1, so the
  // escalation just extends what is already animating out.
  function blankPressed(button) {
    if (button !== Qt.LeftButton) return
    var now = Date.now()
    if (drawerLevel === 1 && now - lastChevronPress < 400) {
      drawerLevel = 2
      lastChevronPress = 0
      return
    }
    lastChevronPress = now
    drawerLevel = drawerLevel === 0 ? 1 : 0
  }

  // The drawer never lingers: five seconds after the latest opening (a blank
  // click or an escalation) it folds itself shut again. Popups opened from it
  // hold it open past the deadline instead of yanking it away underneath the
  // pointer, and once they close, the drawer goes with them.
  Timer {
    id: autoHideTimer
    interval: 5000
    onTriggered: {
      if (root.trayMenuOpen || root.managePopupOpen || root.barDragging
          || (root.bar && root.bar.traySectionPopoutOpen === true)) {
        restart()
        return
      }
      root.lastChevronPress = 0
      root.drawerLevel = 0
    }
  }

  // A tray-section widget's layout entry, looked up by id.
  function trayEntry(id) {
    var layout = bar && bar.layoutConfig
    if (!layout || !Array.isArray(layout.tray)) return null
    for (var i = 0; i < layout.tray.length; i++) {
      if (TrayModel.entryId(layout.tray[i]) === id) return layout.tray[i]
    }
    return null
  }

  // ---- the tier list behind the manager popup ----
  // The bar's own drag and drop only knows sections: dragging a widget out of
  // the drawer lands it in `right`, which is why pinning works. There is no
  // drop target for a *tier*, so a widget can leave the drawer but never be
  // dragged into the always-hidden one. The popup's list is that missing
  // control: one row per widget, three buttons, written straight into the
  // layout through the same config API the bar itself drags with.
  property var tierRows: []

  // Structure, not content: this widget, the clock and the spacer.
  readonly property var tierExcluded: ["aber.tray", "omarchy.clock", "omarchy.spacer"]

  readonly property var tierNames: ({
    "omarchy.menu": "应用菜单",
    "omarchy.indicators": "指示点",
    "omarchy.elsewhen": "世界时钟",
    "omarchy.weather": "天气",
    "omarchy.system-update": "系统更新",
    "omarchy.keyboard-layout": "键盘布局",
    "omarchy.agents": "AI agents",
    "omarchy.monitor": "显示 / 亮度",
    "superwhisper.panel": "语音听写",
    "omarchy.network": "网络",
    "omarchy.bluetooth": "蓝牙",
    "omarchy.audio": "音量",
    "omarchy.power": "电源"
  })

  // "right" (pinned on the bar), "tray" (single click), "hidden" (double
  // click), or "" for a widget that is not in either section at all.
  function tierOf(id) {
    var layout = bar && bar.layoutConfig ? bar.layoutConfig : null
    if (!layout) return ""
    var right = Array.isArray(layout.right) ? layout.right : []
    for (var i = 0; i < right.length; i++) {
      if (TrayModel.entryId(right[i]) === id) return "right"
    }
    var tray = Array.isArray(layout.tray) ? layout.tray : []
    for (var j = 0; j < tray.length; j++) {
      var entry = tray[j]
      if (TrayModel.entryId(entry) !== id) continue
      return entry && entry.tier === "alwaysHidden" ? "hidden" : "tray"
    }
    return ""
  }

  function refreshTierRows() {
    var layout = bar && bar.layoutConfig ? bar.layoutConfig : null
    if (!layout) { tierRows = []; return }
    var rows = []
    var seen = {}
    var groups = ["right", "tray"]
    for (var g = 0; g < groups.length; g++) {
      var list = Array.isArray(layout[groups[g]]) ? layout[groups[g]] : []
      for (var i = 0; i < list.length; i++) {
        var id = TrayModel.entryId(list[i])
        if (!id || seen[id] === true || tierExcluded.indexOf(id) !== -1) continue
        seen[id] = true
        var name = tierNames[id]
        rows.push({
          id: id,
          name: name ? name : String(id).replace(/^omarchy\./, ""),
          tier: tierOf(id)
        })
      }
    }
    tierRows = rows
  }

  // Moves the widget and marks it. A bar-widget plugin has no
  // `bar.shell.mutateShellConfig` (that capability belongs to plugins whose
  // kinds include "bar"), and the layout is owned by the shell anyway, so this
  // goes through the same `omarchy-bar` commands a person would type. The
  // shell handles the two calls in order, and its own config write keeps file
  // and memory in step.
  function setTier(id, tier) {
    var at = -1
    var layout = bar && bar.layoutConfig ? bar.layoutConfig : null
    var right = layout && Array.isArray(layout.right) ? layout.right : []
    for (var i = 0; i < right.length; i++) {
      if (TrayModel.entryId(right[i]) === "omarchy.clock") { at = i; break }
    }

    if (tier === "right") {
      var toRight = ["omarchy-bar", "move", id, "--section", "right"]
      if (at >= 0) toRight.push("--index", String(at))
      Util.execArgv(toRight)
      // Pinned widgets carry no tier; a stale one would hide the widget the
      // day it went back to the drawer.
      Util.execArgv(["omarchy-bar", "set", id, "tier", "null", "--json"])
    } else {
      Util.execArgv(["omarchy-bar", "move", id, "--section", "tray"])
      Util.execArgv(tier === "hidden"
        ? ["omarchy-bar", "set", id, "tier", "alwaysHidden"]
        : ["omarchy-bar", "set", id, "tier", "null", "--json"])
    }

    // Both commands answer through the shell, so the rows are refreshed on the
    // layout change; this only covers a call the shell drops.
    tierRefresh.restart()
  }

  Timer {
    id: tierRefresh
    interval: 400
    onTriggered: root.refreshTierRows()
  }

  // The bar parents the section's widget slots under sectionHost (Loader >
  // ModuleList > ModuleSlot). Each slot's entry may carry a tier: one marked
  // "alwaysHidden" only shows on the double-clicked drawer; the rest show
  // whenever the drawer opens. A widget that should always sit on the bar is
  // not tiered here at all — it belongs in a real section, which
  // `omarchy bar move <id> --section right` does.
  function applyWidgetTiers() {
    if (!sectionHost || !sectionHost.children) return
    for (var i = 0; i < sectionHost.children.length; i++) {
      var holder = sectionHost.children[i]
      var lists = [holder]
      if (holder && holder.item) lists.push(holder.item)
      for (var l = 0; l < lists.length; l++) {
        var kids = lists[l].children || []
        for (var j = 0; j < kids.length; j++) {
          var slot = kids[j]
          if (!slot || !slot.moduleName) continue
          var entry = trayEntry(slot.moduleName)
          slot.visible = !(entry && entry.tier === "alwaysHidden" && drawerLevel < 2)
        }
      }
    }
  }

  onDrawerLevelChanged: {
    applyWidgetTiers()
    syncReveal()
    // Any way the drawer comes open starts the five-second countdown.
    if (drawerLevel > 0) autoHideTimer.restart()
    else autoHideTimer.stop()
  }
  onSectionHostChanged: applyWidgetTiers()

  Connections {
    target: sectionHost
    // Slots come and go as the bar builds the section; reapply so a
    // late-loaded widget never outlives its tier.
    function onChildrenChanged() { Qt.callLater(root.applyWidgetTiers) }
  }

  Connections {
    target: bar
    function onLayoutConfigChanged() {
      Qt.callLater(root.applyWidgetTiers)
      Qt.callLater(root.refreshTierRows)
    }
  }

  onManagePopupOpenChanged: if (managePopupOpen) refreshTierRows()

  // The drawer has no button of its own: the empty middle of the bar is the
  // toggle. `bar` is the plugin API object, not the bar item, so the strip is
  // found by walking up from this widget instead: root -> Loader -> WidgetHost
  // -> slot -> RightModules (region "right") -> the strip that lays out left,
  // center and right. The catcher spans the gap between the left and right
  // sections, so it tracks whatever the layout leaves empty. A right click
  // there opens the tray manager popup.
  property var blankArea: null

  function modulesStrip() {
    var node = root.parent
    var right = null
    while (node) {
      if (node.region === "right") right = node
      node = node.parent
    }
    if (!right || !right.parent) return null
    var strip = right.parent
    var left = null
    for (var i = 0; i < strip.children.length; i++) {
      var child = strip.children[i]
      if (child && child.region === "left") { left = child; break }
    }
    return { strip: strip, left: left, right: right }
  }

  function installBlankClick() {
    if (blankArea) return
    var found = modulesStrip()
    if (!found) return
    blankArea = blankClickComponent.createObject(found.strip, {
      leftMods: found.left,
      rightMods: found.right
    })
    if (!blankArea) console.warn("aber.tray: could not create the blank-click catcher")
  }

  Component {
    id: blankClickComponent
    MouseArea {
      id: catcher
      property Item leftMods: null
      property Item rightMods: null
      // The sections are laid out by hand, so their edges are known only after
      // the first layout pass; bind to them rather than sampling them once.
      readonly property real leftEdge: leftMods ? leftMods.x + leftMods.width + Style.space(4) : 0
      readonly property real rightEdge: rightMods ? rightMods.x - Style.space(4) : 0
      x: leftEdge
      width: Math.max(0, rightEdge - leftEdge)
      y: 0
      height: parent ? parent.height : 0
      visible: width > 0
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) {
          root.managePopupOpen = !root.managePopupOpen
          return
        }
        root.blankPressed(mouse.button)
      }
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: !blankArea
    onTriggered: installBlankClick()
  }

  visible: pinnedItems.length > 0 || hasDrawer
  clip: false
  implicitWidth: root.vertical ? root.barSize : trayContent.implicitWidth
  implicitHeight: root.vertical ? trayContent.implicitHeight : root.barSize

  Behavior on revealProgress {
    NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic }
  }

  // A shorter, softer ease for the tier change, which moves far less.
  Behavior on drawerExtentSmooth {
    NumberAnimation { duration: Math.round(root.animationDuration / 2); easing.type: Easing.OutCubic }
  }

  // The section from `start`, `length` long along the bar, as far as the
  // drawer's clip from `clipStart`, `clipLength` long, shows it
  // (TrayModel.shownSpan).
  function shownSection(clipStart, clipLength, start, length) {
    var span = TrayModel.shownSpan(clipStart, clipLength, start, length)
    if (!span) return null
    return vertical
      ? { x: 0, y: span.start, width: barSize, height: span.length }
      : { x: span.start, y: 0, width: span.length, height: barSize }
  }

  Loader {
    id: trayContent
    anchors.fill: parent
    sourceComponent: root.vertical ? verticalTray : horizontalTray
  }

  Component {
    id: horizontalTray

    Item {
      id: horizontalTrayRoot

      readonly property var sectionShown: root.shownSection(drawerArea.x + trayClip.x, trayClip.width, drawerArea.x + trayClip.x + drawerContent.x + section.x, section.width)

      implicitWidth: pinnedRow.implicitWidth + root.revealExtent
      implicitHeight: root.barSize

      Item {
        id: drawerArea
        x: root.fixedAtStart ? pinnedRow.implicitWidth : 0
        width: root.revealExtent
        height: root.barSize
        visible: root.hasDrawer

        // The icons and the tray section travel out from beside the pinned
        // icons, the section nearest them.
        Item {
          id: trayClip
          x: 0
          anchors.verticalCenter: parent.verticalCenter
          width: root.revealExtent
          height: root.barSize
          clip: true

          Item {
            id: drawerContent
            x: root.fixedAtStart ? root.revealExtent - root.drawerExtent : 0
            width: root.drawerExtent
            height: root.barSize

            Row {
              id: trayIcons
              x: root.fixedAtStart ? root.sectionExtent : 0
              anchors.verticalCenter: parent.verticalCenter
              spacing: root.trayItemGap
              layer.enabled: true

              Repeater {
                model: root.drawerItems
                TrayItem {}
              }
            }

            // Placed by hand: a Row leaves a child with no width where it
            // was, and an empty section has none.
            SectionArea {
              id: section
              x: root.fixedAtStart ? 0 : trayIcons.width
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }
      }

      Row {
        id: pinnedRow
        x: root.fixedAtStart ? 0 : drawerArea.width
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.trayItemGap
        leftPadding: !root.fixedAtStart && root.pinnedItems.length > 0 && root.allItems.length > 0 ? root.trayJoinGap : 0
        rightPadding: root.fixedAtStart && root.pinnedItems.length > 0 && root.allItems.length > 0 ? root.trayJoinGap : 0
        Repeater {
          model: root.pinnedItems
          TrayItem {}
        }
      }
    }
  }

  Component {
    id: verticalTray

    Item {
      id: verticalTrayRoot

      readonly property var sectionShown: root.shownSection(drawerArea.y + trayClip.y, trayClip.height, drawerArea.y + trayClip.y + drawerContent.y + section.y, section.height)

      implicitWidth: root.barSize
      implicitHeight: pinnedCol.implicitHeight + root.revealExtent

      Item {
        id: drawerArea
        y: root.fixedAtStart ? pinnedCol.implicitHeight : 0
        width: root.barSize
        height: root.revealExtent
        visible: root.hasDrawer

        // The icons and the tray section travel out from beside the pinned
        // icons, the section nearest them.
        Item {
          id: trayClip
          y: 0
          anchors.horizontalCenter: parent.horizontalCenter
          width: root.barSize
          height: root.revealExtent
          clip: true

          Item {
            id: drawerContent
            y: root.fixedAtStart ? root.revealExtent - root.drawerExtent : 0
            width: root.barSize
            height: root.drawerExtent

            Column {
              id: trayIcons
              y: root.fixedAtStart ? root.sectionExtent : 0
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: root.trayItemGap
              layer.enabled: true

              Repeater {
                model: root.drawerItems
                TrayItem {}
              }
            }

            // Placed by hand: a Column leaves a child with no height where it
            // was, and an empty section has none.
            SectionArea {
              id: section
              y: root.fixedAtStart ? 0 : trayIcons.height
              anchors.horizontalCenter: parent.horizontalCenter
            }
          }
        }
      }

      Column {
        id: pinnedCol
        y: root.fixedAtStart ? 0 : drawerArea.height
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.trayItemGap
        topPadding: !root.fixedAtStart && root.pinnedItems.length > 0 && root.allItems.length > 0 ? root.trayJoinGap : 0
        bottomPadding: root.fixedAtStart && root.pinnedItems.length > 0 && root.allItems.length > 0 ? root.trayJoinGap : 0
        Repeater {
          model: root.pinnedItems
          TrayItem {}
        }
      }
    }
  }

  PopupCard {
    id: managePopup
    anchorItem: root
    owner: root
    bar: root.bar
    open: root.managePopupOpen
    contentWidth: managePopup.fittedContentWidth(Style.space(300))
    contentHeight: managePopup.fittedContentHeight(manageColumn.implicitHeight)

    Column {
      id: manageColumn
      anchors.fill: parent
      spacing: Style.space(8)

      Text {
        text: Commons.I18n.t("tray.title")
        textFormat: Text.PlainText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }

      Text {
        text: "点一下菜单栏空白处显示「隐藏」档，快点两下再显示「始终隐藏」档，5 秒后自动收起。右键空白处打开本面板。"
        textFormat: Text.PlainText
        color: Qt.darker(root.foreground, 1.4)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
        width: parent.width
      }

      // The widgets the drawer or the bar itself carries, each with its tier.
      Repeater {
        model: root.tierRows

        delegate: Item {
          id: tierRow
          required property var modelData
          width: manageColumn.width
          implicitHeight: Style.space(28)

          readonly property string widgetId: String(modelData.id || "")

          Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: tierButtons.left
            anchors.rightMargin: Style.space(8)
            text: tierRow.modelData.name
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          Row {
            id: tierButtons
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            spacing: Style.space(4)

            // 常驻 / 隐藏 / 始终隐藏: the tier the widget lives in is the raised one.
            Button {
              text: "常驻"
              selected: tierRow.modelData.tier === "right"
              foreground: selected ? root.foreground : Qt.darker(root.foreground, 1.5)
              horizontalPadding: Style.space(8)
              verticalPadding: Style.space(3)
              fontSize: Style.font.caption
              onClicked: root.setTier(tierRow.widgetId, "right")
            }

            Button {
              text: "隐藏"
              selected: tierRow.modelData.tier === "tray"
              foreground: selected ? root.foreground : Qt.darker(root.foreground, 1.5)
              horizontalPadding: Style.space(8)
              verticalPadding: Style.space(3)
              fontSize: Style.font.caption
              onClicked: root.setTier(tierRow.widgetId, "tray")
            }

            Button {
              text: "始终隐藏"
              selected: tierRow.modelData.tier === "hidden"
              foreground: selected ? root.foreground : Qt.darker(root.foreground, 1.5)
              horizontalPadding: Style.space(8)
              verticalPadding: Style.space(3)
              fontSize: Style.font.caption
              onClicked: root.setTier(tierRow.widgetId, "hidden")
            }
          }
        }
      }

      // Anything the tier list does not cover — a widget that is on the bar but
      // in no drawer section — still gets told about here.
      Text {
        visible: root.tierRows.length === 0
        text: "栏上没有可归入托盘的部件"
        textFormat: Text.PlainText
        color: Qt.darker(root.foreground, 1.5)
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.italic: true
      }

      // The apps' own tray icons keep their own two buttons below.
      Item {
        width: manageColumn.width
        implicitHeight: Style.space(11)

        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          height: 1
          color: Commons.Color.popups.border
          opacity: 0.45
        }
      }

      Text {
        textFormat: Text.PlainText
        text: "应用图标"
        color: Qt.darker(root.foreground, 1.4)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Text {
        visible: root.allItems.length === 0
        text: Commons.I18n.t("tray.empty")
        textFormat: Text.PlainText
        color: Qt.darker(root.foreground, 1.5)
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.italic: true
      }

      Repeater {
        model: root.allItems
        delegate: Item {
          id: rowRoot
          required property var modelData
          required property int index
          width: manageColumn.width
          implicitHeight: 28

          readonly property string itemId: String(modelData.id || "")
          readonly property string displayName: {
            var t = String(modelData.title || "").trim()
            if (t) return t
            var tt = String(modelData.tooltipTitle || "").trim()
            if (tt) return tt
            var id = String(modelData.id || "")
            var slash = id.lastIndexOf("/")
            return slash !== -1 ? id.substring(slash + 1) : (id || Commons.I18n.t("tray.unknown"))
          }
          readonly property bool isPinned: root.pinnedIds.indexOf(itemId) !== -1
          readonly property bool isHidden: root.hiddenIds.indexOf(itemId) !== -1

          TrayIcon {
            id: rowIcon
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            width: 16
            height: 16
            icon: rowRoot.modelData.icon
          }

          Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: rowIcon.right
            anchors.leftMargin: Style.space(10)
            anchors.right: rowHideBtn.left
            anchors.rightMargin: Style.space(8)
            text: rowRoot.displayName
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          Button {
            id: rowPinBtn
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            iconText: "\uf08d"
            text: rowRoot.isPinned ? Commons.I18n.t("tray.unpin") : Commons.I18n.t("tray.pin")
            foreground: root.foreground
            horizontalPadding: 8
            verticalPadding: 3
            iconSize: Style.font.bodySmall
            fontSize: Style.font.bodySmall
            onClicked: root.togglePin(rowRoot.itemId)
          }

          Button {
            id: rowHideBtn
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: rowPinBtn.left
            anchors.rightMargin: Style.space(6)
            iconText: "\uf06e"
            text: rowRoot.isHidden ? Commons.I18n.t("tray.show") : Commons.I18n.t("tray.hide")
            foreground: root.foreground
            horizontalPadding: 8
            verticalPadding: 3
            iconSize: Style.font.bodySmall
            fontSize: Style.font.bodySmall
            onClicked: root.toggleHide(rowRoot.itemId)
          }
        }
      }
    }
  }

  QsMenuOpener {
    id: trayMenuOpener
    menu: root.activeTrayItem ? root.activeTrayItem.menu : null
  }

  PopupCard {
    id: trayMenuPopup
    anchorItem: root.activeTrayAnchor || root
    owner: root
    bar: root.bar
    open: root.trayMenuOpen
    // The card fades out over 140ms (visible stays true for that whole time --
    // see PopupCard's own visible: open || card.opacity > 0), so resetting on
    // "open" would swap a live submenu for the root menu mid-fade: a visible
    // flash, and a resize/reposition if the two have different geometry. Wait
    // for the fade to actually finish. Switching to a different tray item
    // still resets immediately, from openTrayMenu() itself.
    onVisibleChanged: if (!visible) root.resetTrayMenu()
    padding: Style.space(8)
    borderColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.45)
    contentWidth: trayMenuPopup.fittedContentWidth(Style.space(232))
    contentHeight: trayMenuPopup.fittedContentHeight(menuHeaderHeight + trayMenuColumn.implicitHeight, Style.space(420))

    // Column skips invisible children but keeps reporting their height, so
    // read the header's extent through its own visibility.
    readonly property int menuHeaderHeight: menuHeader.visible ? menuHeader.implicitHeight : 0

    Column {
      id: trayMenuLayout
      anchors.fill: parent
      spacing: 0

      // Header for a drilled-into submenu: names where we are and walks back
      // out. Pinned above the Flickable rather than scrolling with the rows,
      // so the way back stays reachable in a submenu taller than the card.
      // Only present below the root level, so the root menu is unchanged.
      Column {
        id: menuHeader
        visible: root.submenuDepth > 0
        width: trayMenuLayout.width
        spacing: 0

        Item {
          id: menuBackRow
          width: menuHeader.width
          implicitHeight: Style.space(30)

          Rectangle {
            anchors.fill: parent
            radius: Math.max(2, Style.cornerRadius)
            color: backMouse.containsMouse ? Style.hoverFillFor(root.foreground, root.foreground) : "transparent"
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            width: Style.space(22)
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            // Back points against the reading direction.
            text: Commons.I18n.rightToLeft ? "\u203a" : "\u2039"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Style.space(28)
            anchors.right: parent.right
            anchors.rightMargin: Style.space(10)
            text: root.currentTitle
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          MouseArea {
            id: backMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.menuLevelSettling) return
              // Reset before the model swap so the parent level shows from
              // the top (same ordering as the row delegate below).
              trayMenuFlick.contentY = 0
              root.leaveSubmenu()
            }
          }
        }

        Item {
          width: menuHeader.width
          implicitHeight: Style.space(11)

          Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(10)
            anchors.right: parent.right
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: Commons.Color.popups.border
            opacity: 0.45
          }
        }
      }

      Flickable {
        id: trayMenuFlick
        width: trayMenuLayout.width
        height: trayMenuLayout.height - trayMenuPopup.menuHeaderHeight
        contentWidth: width
        contentHeight: trayMenuColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: trayMenuColumn
          width: trayMenuFlick.width
          spacing: 0

          Repeater {
            model: root.currentChildren

            delegate: Item {
              id: menuRow
              required property var modelData
              required property int index

              readonly property string rowText: String(modelData.text || "")
              readonly property string activeTitle: root.activeTrayItem ? String(root.activeTrayItem.title || root.activeTrayItem.id || "") : ""
              // Both only ever describe the root menu; inside a submenu the first
              // rows are real entries and must not be swallowed.
              readonly property bool atRoot: root.submenuDepth === 0
              readonly property bool rootTitleEntry: atRoot && index === 0 && modelData.hasChildren && rowText.toLowerCase() === activeTitle.toLowerCase()
              readonly property bool leadingSeparator: atRoot && modelData.isSeparator && index <= 1
              readonly property bool hiddenRow: rootTitleEntry || leadingSeparator

              visible: !hiddenRow
              width: trayMenuColumn.width
              implicitHeight: hiddenRow ? 0 : (modelData.isSeparator ? Style.space(11) : Style.space(30))
              opacity: modelData.enabled ? 1.0 : 0.45

              Rectangle {
                visible: menuRow.modelData.isSeparator
                anchors.left: parent.left
                anchors.leftMargin: Style.space(10)
                anchors.right: parent.right
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                height: 1
                color: Commons.Color.popups.border
                opacity: 0.45
              }

              Rectangle {
                visible: !menuRow.modelData.isSeparator
                anchors.fill: parent
                radius: Math.max(2, Style.cornerRadius)
                color: rowMouse.containsMouse && menuRow.modelData.enabled ? Style.hoverFillFor(root.foreground, root.foreground) : "transparent"
              }

              Text {
                textFormat: Text.PlainText
                visible: !menuRow.modelData.isSeparator && menuRow.modelData.buttonType !== QsMenuButtonType.None
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                width: Style.space(22)
                horizontalAlignment: Text.AlignHCenter
                text: menuRow.modelData.checkState === Qt.Checked ? "\uf00c" : ""
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Image {
                id: menuIcon
                visible: !menuRow.modelData.isSeparator && String(menuRow.modelData.icon || "") !== ""
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Style.space(24)
                width: Style.space(16)
                height: Style.space(16)
                fillMode: Image.PreserveAspectFit
                // Decode at physical pixels: IconImage uses the logical size,
                // which leaves PNG icons upscaled and blurry on HiDPI displays.
                sourceSize.width: width * Screen.devicePixelRatio
                sourceSize.height: height * Screen.devicePixelRatio
                source: menuRow.modelData.icon
              }

              Text {
                textFormat: Text.PlainText
                visible: !menuRow.modelData.isSeparator
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: menuIcon.visible ? Style.space(46) : Style.space(28)
                anchors.right: submenuGlyph.left
                anchors.rightMargin: Style.space(8)
                text: menuRow.rowText
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }

              Text {
                id: submenuGlyph
                visible: !menuRow.modelData.isSeparator && menuRow.modelData.hasChildren
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Style.space(10)
                textFormat: Text.PlainText
                text: Commons.I18n.rightToLeft ? "\u2039" : "\u203a"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: !menuRow.modelData.isSeparator && menuRow.modelData.enabled
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                  if (root.menuLevelSettling) return
                  if (menuRow.modelData.hasChildren) {
                    // Reset scroll BEFORE swapping the model: the swap destroys
                    // this delegate synchronously and ids stop resolving after.
                    trayMenuFlick.contentY = 0
                    root.enterSubmenu(menuRow.modelData, menuRow.rowText)
                  } else {
                    menuRow.modelData.triggered()
                    root.close()
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  // Renders a tray icon, recoloring symbolic icons to the bar foreground so
  // they stay visible on any theme (a raw symbolic icon keeps its baked-in
  // fill and disappears against a matching background).
  component TrayIcon: Item {
    id: trayIconRoot
    required property var icon
    readonly property bool symbolic: root.iconIsSymbolic(icon)

    Image {
      id: trayIconImage
      anchors.fill: parent
      fillMode: Image.PreserveAspectFit
      // Decode at physical pixels: IconImage uses the logical size,
      // which leaves PNG icons upscaled and blurry on HiDPI displays.
      sourceSize.width: Math.round(Math.min(width, height) * Screen.devicePixelRatio)
      sourceSize.height: Math.round(Math.min(width, height) * Screen.devicePixelRatio)
      source: root.trayIconSource(trayIconRoot.icon)
      // Kept as a hidden layer so the effect can sample it as a texture.
      visible: !trayIconRoot.symbolic
      layer.enabled: trayIconRoot.symbolic
    }

    // Paint the foreground through the icon's alpha. MultiEffect's colorization
    // keeps the source's lightness, so a dark fill stayed dark on a dark bar.
    Rectangle {
      anchors.fill: trayIconImage
      color: root.foreground
      visible: trayIconRoot.symbolic
      layer.enabled: trayIconRoot.symbolic
      layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: trayIconImage
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
      }
    }
  }

  // The tray section's place in the drawer: the bar parents its widgets here.
  // Empty, it takes no room.
  component SectionArea: Item {
    id: sectionArea
    implicitWidth: childrenRect.width
    implicitHeight: childrenRect.height

    Component.onCompleted: root.sectionHost = sectionArea
    // The bar can tear this area down after the widget itself is gone
    // (a plugin rescan destroys them in its own order), so unregister
    // only while the widget is still there to unregister from.
    Component.onDestruction: if (root && root.sectionHost === sectionArea) root.sectionHost = null
  }

  component TrayItem: Item {
    id: trayItemRoot

    required property var modelData

    visible: modelData.status !== Status.Passive
    implicitWidth: visible ? root.trayItemExtent : 0
    implicitHeight: visible ? root.trayItemExtent : 0

    function displayMenu(mouse) {
      root.openTrayMenu(trayItemRoot.modelData, trayItemRoot, mouse)
    }

    TrayIcon {
      x: Math.round((parent.width - width) / 2)
      y: Math.round((parent.height - height) / 2)
      width: Style.bar.iconSize
      height: Style.bar.iconSize
      icon: trayItemRoot.modelData.icon
    }

    MouseArea {
      id: mouseArea
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: if (root.bar) root.bar.showTooltip(trayItemRoot, root.trayTooltip(modelData))
      onExited: if (root.bar) root.bar.hideTooltip(trayItemRoot)
      onPressed: function(mouse) {
        if (mouse.button === Qt.RightButton) {
          trayItemRoot.displayMenu(mouse)
          mouse.accepted = true
        }
      }
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) {
          mouse.accepted = true
        } else if (mouse.button === Qt.MiddleButton) {
          trayItemRoot.modelData.secondaryActivate()
        } else if (trayItemRoot.modelData.onlyMenu) {
          trayItemRoot.displayMenu(mouse)
        } else {
          trayItemRoot.modelData.activate()
        }
      }
      // A double-click's second click lands here, not in onClicked.
      onDoubleClicked: function(mouse) {
        if (mouse.button === Qt.LeftButton && TrayModel.activatesOnDoubleClick(trayItemRoot.modelData))
          trayItemRoot.modelData.activate()
      }
      onWheel: function(wheel) {
        trayItemRoot.modelData.scroll(wheel.angleDelta.y, false)
      }
    }

    readonly property bool tooltipHovered: visible && opacity > 0 && mouseArea.containsMouse
  }
}

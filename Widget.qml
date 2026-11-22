import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons

BarWidget {
  id: root
  moduleName: "io.github.mdpwbe-sys.vram"

  property int vramUsed: 0
  property int vramTotal: 0
  property int ramUsed: 0
  property int ramTotal: 0
  property bool vramKnown: false
  property bool ramKnown: false
  property bool freeing: false

  readonly property string pluginRoot: Quickshell.env("HOME") + "/.config/omarchy/plugins/" + moduleName
  readonly property string statusScript: pluginRoot + "/vram-status.sh"
  readonly property string freeScript: pluginRoot + "/free-model-vram.sh"
  readonly property string comfyUrl: String(setting("comfyUrl", "http://127.0.0.1:8188"))
  readonly property string ollamaHost: String(setting("ollamaHost", "127.0.0.1:11434"))
  readonly property int meterWidth: Style.space(30)
  readonly property real warnAt: {
    var n = Number(setting("warnPercent", 85))
    if (!isFinite(n)) n = 85
    return Math.max(0.5, Math.min(1, n / 100))
  }
  readonly property int refreshSec: {
    var n = Number(setting("refreshSec", 3))
    if (!isFinite(n)) n = 3
    return Math.max(2, Math.min(60, Math.round(n)))
  }
  readonly property real vramRatio: vramKnown && vramTotal > 0 ? Math.min(1, vramUsed / vramTotal) : 0
  readonly property real ramRatio: ramKnown && ramTotal > 0 ? Math.min(1, ramUsed / ramTotal) : 0
  readonly property color ink: bar && bar.barForeground ? bar.barForeground : Commons.Color.foreground
  readonly property color hot: bar && bar.urgent ? bar.urgent : Commons.Color.urgent
  readonly property string tip: {
    var levels = vramKnown
      ? strings.t("levels")
        .arg(Commons.I18n.formatNumber(vramUsed / 1024, 1))
        .arg(Commons.I18n.formatNumber(vramTotal / 1024, 1))
        .arg(Commons.I18n.formatNumber(ramUsed / 1024, 1))
        .arg(Commons.I18n.formatNumber(ramTotal / 1024, 1))
      : strings.t("levelsRam")
        .arg(Commons.I18n.formatNumber(ramUsed / 1024, 1))
        .arg(Commons.I18n.formatNumber(ramTotal / 1024, 1))
    return levels + "\n" + strings.t(freeing ? "busy" : "clear")
  }

  function refresh() {
    if (!probe.running) probe.running = true
  }

  function clear() {
    if (freeing || freer.running) return
    freeing = true
    freer.running = true
  }

  function triggerPress(mouseButton) {
    if (mouseButton === Qt.LeftButton) clear()
  }

  function takeReading(line) {
    var parts = String(line).trim().split(" ")
    if (parts.length !== 4) return
    var nums = []
    for (var i = 0; i < 4; i++) {
      if (!/^[0-9]+$/.test(parts[i])) return
      nums.push(parseInt(parts[i], 10))
    }
    vramUsed = nums[0]
    vramTotal = nums[1]
    ramUsed = nums[2]
    ramTotal = nums[3]
    vramKnown = nums[1] > 0
    ramKnown = nums[3] > 0
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  Process {
    id: probe
    command: [root.statusScript]
    stdout: SplitParser {
      onRead: function(line) { root.takeReading(line) }
    }
  }

  Process {
    id: freer
    command: [root.freeScript, root.comfyUrl, root.ollamaHost]
    onExited: function(code, status) {
      root.freeing = false
      root.refresh()
    }
  }

  Timer {
    interval: root.refreshSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  component Meter: Item {
    id: meter
    property real ratio: 0
    property bool known: false
    property real warnAt: 0.85
    property color ink: "#cacccc"
    property color hot: "#a55555"
    readonly property bool warn: known && ratio >= warnAt
    height: Style.space(3)

    Rectangle {
      anchors.fill: parent
      radius: height / 2
      color: meter.ink
      opacity: 0.22
    }

    Rectangle {
      width: meter.known ? Math.max(meter.ratio > 0 ? 2 : 0, meter.width * Math.min(1, meter.ratio)) : 0
      height: parent.height
      radius: height / 2
      color: meter.warn ? meter.hot : meter.ink

      Behavior on width {
        NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic }
      }
    }
  }

  BarIconButton {
    id: button
    bar: root.bar
    fixedWidth: root.vertical ? Style.bar.iconSlot : root.meterWidth + Style.space(6) + Style.bar.iconSlot
    text: "󰍛"
    iconComponent: blankIcon
    active: root.freeing
    tooltipText: root.tip
    onPressed: function(mouseButton) { root.triggerPress(mouseButton) }

    Component {
      id: blankIcon
      Item { width: 1; height: 1 }
    }

    Row {
      anchors.centerIn: parent
      spacing: Style.space(6)
      scale: button.pressScale

      Column {
        id: meters
        visible: !root.vertical
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)
        Meter {
          width: root.meterWidth
          ratio: root.vramRatio
          known: root.vramKnown
          warnAt: root.warnAt
          ink: root.ink
          hot: root.hot
        }
        Meter {
          width: root.meterWidth
          ratio: root.ramRatio
          known: root.ramKnown
          warnAt: root.warnAt
          ink: root.ink
          hot: root.hot
        }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: "󰍛"
        font.family: button.fontFamily
        font.pixelSize: Style.bar.iconFont
        color: button.active && button.useActiveColor ? button.activeColor : button.foreground
        renderType: Text.NativeRendering
      }
    }
  }
}

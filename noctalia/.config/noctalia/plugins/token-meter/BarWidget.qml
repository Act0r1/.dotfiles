import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property var mainInstance: pluginApi ? pluginApi.mainInstance : null
  readonly property var today: mainInstance && mainInstance.stats && mainInstance.stats.periods
    ? mainInstance.stats.periods.today
    : ({ totalTokens: 0, cacheRate: 0, cost: 0 })
  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool vertical: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)

  function compact(value) {
    const number = Number(value || 0);
    if (number >= 1000000000)
      return (number / 1000000000).toFixed(1) + "B";
    if (number >= 1000000)
      return (number / 1000000).toFixed(1) + "M";
    if (number >= 1000)
      return (number / 1000).toFixed(1) + "K";
    return Math.round(number).toString();
  }

  implicitWidth: vertical ? capsuleHeight : content.implicitWidth + Style.marginM * 2
  implicitHeight: vertical ? content.implicitHeight + Style.marginM * 2 : capsuleHeight

  Rectangle {
    anchors.fill: parent
    radius: Style.radiusL
    color: mouseArea.containsMouse ? Color.mHover : "transparent"

    Behavior on color {
      enabled: !Color.isTransitioning
      ColorAnimation {
        duration: Style.animationFast
      }
    }
  }

  GridLayout {
    id: content
    anchors.centerIn: parent
    columns: root.vertical ? 1 : 3
    rows: root.vertical ? 3 : 1
    columnSpacing: Style.marginS
    rowSpacing: Style.marginXS

    NIcon {
      icon: "brain"
      pointSize: Style.getBarFontSizeForScreen(root.screenName) * 1.15
      color: Color.mPrimary
    }

    NText {
      text: root.compact(root.today.totalTokens)
      pointSize: Style.getBarFontSizeForScreen(root.screenName)
      font.weight: Font.Bold
      color: Color.mOnSurface
    }

    NText {
      text: "C " + Math.round(Number(root.today.cacheRate || 0) * 100) + "%"
      pointSize: Style.getBarFontSizeForScreen(root.screenName) * 0.78
      font.weight: Font.DemiBold
      color: Color.mSecondary
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor

    onEntered: TooltipService.show(
      root,
      "Last 24h: " + root.compact(root.today.totalTokens) + " processed tokens · "
        + Math.round(Number(root.today.cacheRate || 0) * 100) + "% context reused",
      BarService.getTooltipDirection(root.screenName)
    )
    onExited: TooltipService.hide()
    onClicked: function(mouse) {
      TooltipService.hide();
      if (mouse.button === Qt.RightButton && root.mainInstance)
        root.mainInstance.openDashboard();
      else if (root.pluginApi)
        root.pluginApi.togglePanel(root.screen, root);
    }
  }
}

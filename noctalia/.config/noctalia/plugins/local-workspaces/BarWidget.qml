import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Commons

Item {
  id: root

  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0
  property var pluginApi: null
  property real wheelDelta: 0

  readonly property var mainInstance: pluginApi ? pluginApi.mainInstance : null
  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool vertical: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real pillSize: Style.toOdd(capsuleHeight * 0.7)

  implicitWidth: vertical ? capsuleHeight : content.implicitWidth
  implicitHeight: vertical ? content.implicitHeight : capsuleHeight
  visible: workspaceRepeater.count > 0

  Grid {
    id: content
    anchors.centerIn: parent
    columns: root.vertical ? 1 : Math.max(1, workspaceRepeater.count)
    rows: root.vertical ? Math.max(1, workspaceRepeater.count) : 1
    spacing: 3

    Repeater {
      id: workspaceRepeater
      model: root.mainInstance ? root.mainInstance.workspaces : []

      delegate: Item {
        id: workspaceItem

        required property var modelData
        readonly property bool focused: root.mainInstance
          && modelData.id === root.mainInstance.focusedId
        readonly property bool urgent: modelData.urgent === true && !focused
        readonly property real activeLength: root.pillSize * 2.2

        width: root.vertical
          ? root.capsuleHeight
          : focused || urgent ? activeLength : root.pillSize
        height: root.vertical
          ? focused || urgent ? activeLength : root.pillSize
          : root.capsuleHeight

        Rectangle {
          id: pill
          anchors.centerIn: parent
          width: root.vertical ? root.pillSize : parent.width
          height: root.vertical ? parent.height : root.pillSize
          radius: Style.radiusM
          color: mouseArea.containsMouse
            ? Color.mHover
            : workspaceItem.focused
              ? Color.resolveColorKey("primary")
              : workspaceItem.urgent ? Color.mError : "transparent"

          Behavior on color {
            enabled: !Color.isTransitioning
            ColorAnimation {
              duration: Style.animationFast
              easing.type: Easing.InOutQuad
            }
          }
        }

        IconImage {
          anchors.centerIn: pill
          width: root.pillSize * 0.78
          height: width
          source: ThemeIcons.iconForAppId(
            workspaceItem.modelData.appId.toLowerCase(),
            "application-x-executable"
          )
        }

        MouseArea {
          id: mouseArea
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true
          onClicked: root.mainInstance.activate(workspaceItem.modelData.id)
        }

        Behavior on width {
          NumberAnimation {
            duration: Style.animationNormal
            easing.type: Easing.OutBack
          }
        }

        Behavior on height {
          NumberAnimation {
            duration: Style.animationNormal
            easing.type: Easing.OutBack
          }
        }
      }
    }
  }

  WheelHandler {
    target: root
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

    onWheel: function(event) {
      if (!root.mainInstance)
        return;

      const dy = event.angleDelta.y;
      const dx = event.angleDelta.x;
      const delta = Math.abs(dy) >= Math.abs(dx) ? dy : dx;

      root.wheelDelta += delta;

      if (Math.abs(root.wheelDelta) < 120)
        return;

      root.mainInstance.switchByOffset(root.wheelDelta > 0 ? -1 : 1);
      root.wheelDelta = 0;
      event.accepted = true;
    }
  }
}

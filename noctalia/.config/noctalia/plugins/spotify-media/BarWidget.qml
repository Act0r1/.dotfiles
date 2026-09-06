import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.Media
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property bool hasPlayer: MediaService.currentPlayer !== null
  readonly property bool isSpotify: pluginApi?.mainInstance?.isSpotify ?? false
  readonly property string displayText: {
    const value = MediaService.trackArtist || MediaService.trackTitle || "Media";
    return value.length > 24 ? value.slice(0, 23) + "…" : value;
  }

  implicitWidth: pill.implicitWidth
  implicitHeight: pill.implicitHeight
  visible: root.hasPlayer

  BarPill {
    id: pill
    screen: root.screen
    forceOpen: true
    icon: root.isSpotify ? "brand-spotify" : "music"
    text: root.displayText
    tooltipText: MediaService.trackTitle + (MediaService.trackArtist ? " — " + MediaService.trackArtist : "")

    onClicked: root.pluginApi?.togglePanel(root.screen, pill)
    onMiddleClicked: MediaService.playPause()
    onWheel: delta => {
      if (delta > 0)
        MediaService.previous();
      else if (delta < 0)
        MediaService.next();
    }
  }
}

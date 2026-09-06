import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Media
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  readonly property bool allowAttach: true
  readonly property var geometryPlaceholder: panelContainer
  readonly property var mainInstance: pluginApi?.mainInstance ?? null
  readonly property bool isSpotify: mainInstance?.isSpotify ?? false

  property real contentPreferredWidth: 455 * Style.uiScaleRatio
  property real contentPreferredHeight: 255 * Style.uiScaleRatio

  anchors.fill: parent

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: header.implicitHeight + Style.margin2M

        RowLayout {
          id: header
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          NIcon {
            icon: root.isSpotify ? "brand-spotify" : "music"
            pointSize: Style.fontSizeL
            color: Color.mPrimary
          }

          NText {
            text: "Media Player"
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
            Layout.fillWidth: true
          }

          NText {
            text: MediaService.playerIdentity || "Media"
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
          }

          NIconButton {
            icon: "close"
            baseSize: Style.baseWidgetSize * 0.8
            tooltipText: "Close"
            onClicked: root.pluginApi?.closePanel(root.pluginApi.panelOpenScreen)
          }
        }
      }

      NBox {
        Layout.fillWidth: true
        Layout.fillHeight: true

        RowLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          NImageRounded {
            Layout.preferredWidth: 110 * Style.uiScaleRatio
            Layout.preferredHeight: 110 * Style.uiScaleRatio
            Layout.alignment: Qt.AlignTop
            radius: Style.radiusL
            imagePath: MediaService.trackArtUrl
            fallbackIcon: "disc"
            fallbackIconSize: Style.fontSizeXXXL * 2
            imageFillMode: Image.PreserveAspectCrop
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Style.marginXS

            NText {
              Layout.fillWidth: true
              text: MediaService.trackTitle || "Nothing playing"
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              elide: Text.ElideRight
            }

            NText {
              Layout.fillWidth: true
              text: MediaService.trackArtist || MediaService.trackAlbum || "Media"
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
              elide: Text.ElideRight
            }

            NSlider {
              Layout.fillWidth: true
              from: 0
              to: 1
              stepSize: 0
              snapAlways: false
              enabled: MediaService.trackLength > 0 && MediaService.canSeek
              value: MediaService.trackLength > 0 ? Math.max(0, Math.min(1, MediaService.currentPosition / MediaService.trackLength)) : 0
              onMoved: MediaService.seekByRatio(value)
            }

            RowLayout {
              Layout.fillWidth: true

              NText {
                text: MediaService.positionString || "0:00"
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
              }

              Item { Layout.fillWidth: true }

              NText {
                text: MediaService.lengthString || "0:00"
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
              }
            }

            RowLayout {
              Layout.alignment: Qt.AlignHCenter
              spacing: Style.marginS

              NIconButton {
                icon: "media-prev"
                enabled: MediaService.currentPlayer !== null && MediaService.canGoPrevious
                tooltipText: "Previous"
                onClicked: MediaService.previous()
              }

              NIconButton {
                icon: MediaService.isPlaying ? "media-pause" : "media-play"
                enabled: MediaService.currentPlayer !== null && MediaService.canPlay
                colorBg: Color.mPrimary
                colorFg: Color.mOnPrimary
                tooltipText: MediaService.isPlaying ? "Pause" : "Play"
                onClicked: MediaService.playPause()
              }

              NIconButton {
                icon: "media-next"
                enabled: MediaService.currentPlayer !== null && MediaService.canGoNext
                tooltipText: "Next"
                onClicked: MediaService.next()
              }

              NIconButton {
                visible: root.isSpotify
                enabled: MediaService.currentPlayer !== null
                icon: "heart"
                baseSize: Style.baseWidgetSize * 0.82
                customRadius: 999
                colorBg: Qt.alpha(Color.mSecondary, 0.16)
                colorFg: Color.mSecondary
                colorBgHover: Color.mSecondary
                colorFgHover: Color.mOnSecondary
                colorBorder: Qt.alpha(Color.mSecondary, 0.5)
                colorBorderHover: Color.mSecondary
                tooltipText: "Like or unlike current Spotify track"
                onClicked: root.mainInstance?.likeTrack()
              }

              NIconButton {
                visible: root.isSpotify
                enabled: MediaService.currentPlayer !== null
                icon: "thumb-down"
                baseSize: Style.baseWidgetSize * 0.82
                customRadius: 999
                colorBg: Qt.alpha(Color.mError, 0.16)
                colorFg: Color.mError
                colorBgHover: Color.mError
                colorFgHover: Color.mOnError
                colorBorder: Qt.alpha(Color.mError, 0.5)
                colorBorderHover: Color.mError
                tooltipText: "Dislike current Spotify track"
                onClicked: root.mainInstance?.dislikeTrack()
              }
            }
          }
        }
      }
    }
  }
}

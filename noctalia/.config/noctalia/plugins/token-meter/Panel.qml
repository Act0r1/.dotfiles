import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true
  property real contentPreferredWidth: 660 * Style.uiScaleRatio
  property real contentPreferredHeight: 560 * Style.uiScaleRatio
  readonly property var mainInstance: pluginApi ? pluginApi.mainInstance : null
  readonly property var today: mainInstance && mainInstance.stats && mainInstance.stats.periods
    ? mainInstance.stats.periods.today
    : ({ totalTokens: 0, input: 0, output: 0, cacheRead: 0, cacheWrite: 0, reasoning: 0, cacheRate: 0, cost: 0, requests: 0, models: [] })

  anchors.fill: parent

  function compact(value) {
    const number = Number(value || 0);
    if (number >= 1000000000)
      return (number / 1000000000).toFixed(2) + "B";
    if (number >= 1000000)
      return (number / 1000000).toFixed(2) + "M";
    if (number >= 1000)
      return (number / 1000).toFixed(1) + "K";
    return Math.round(number).toString();
  }

  function money(value) {
    const number = Number(value || 0);
    if (number > 0 && number < 0.01)
      return "$" + number.toFixed(4);
    return "$" + number.toFixed(2);
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        Rectangle {
          Layout.preferredWidth: 44 * Style.uiScaleRatio
          Layout.preferredHeight: 44 * Style.uiScaleRatio
          radius: Style.radiusM
          color: Color.mPrimary

          NIcon {
            anchors.centerIn: parent
            icon: "brain"
            pointSize: Style.fontSizeXL
            color: Color.mOnPrimary
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          NText {
            text: "Token Meter"
            pointSize: Style.fontSizeXL
            font.weight: Font.Bold
            color: Color.mOnSurface
          }

          NText {
            text: "Pi + Codex + Claude Code · live local analytics"
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
          }
        }

        NButton {
          text: root.mainInstance && root.mainInstance.busy ? "Updating…" : "Refresh"
          icon: root.mainInstance && root.mainInstance.busy ? "loader-2" : "refresh"
          outlined: true
          enabled: !root.mainInstance || !root.mainInstance.busy
          onClicked: root.mainInstance ? root.mainInstance.refresh() : undefined
        }

        NButton {
          text: "Open dashboard"
          icon: "external-link"
          onClicked: root.mainInstance ? root.mainInstance.openDashboard() : undefined
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        Repeater {
          model: [
            { label: "PROCESSED 24H", value: root.compact(root.today.totalTokens), icon: "sparkles", color: Color.mPrimary },
            { label: "CACHE REUSE", value: Math.round(Number(root.today.cacheRate || 0) * 100) + "%", icon: "database", color: Color.mSecondary },
            { label: "REQUESTS", value: root.compact(root.today.requests), icon: "activity", color: Color.mTertiary },
            { label: "API COST", value: "$" + Number(root.today.cost || 0).toFixed(2), icon: "currency-dollar", color: Color.mPrimary }
          ]

          delegate: Rectangle {
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredHeight: 92 * Style.uiScaleRatio
            radius: Style.radiusL
            color: Color.mSurfaceVariant
            border.width: Style.borderS
            border.color: Color.mOutline

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginXS

              RowLayout {
                Layout.fillWidth: true

                NText {
                  Layout.fillWidth: true
                  text: modelData.label
                  pointSize: Style.fontSizeXS
                  font.weight: Font.DemiBold
                  color: Color.mOnSurfaceVariant
                }

                NIcon {
                  icon: modelData.icon
                  pointSize: Style.fontSizeM
                  color: modelData.color
                }
              }

              NText {
                text: modelData.value
                pointSize: Style.fontSizeXL
                font.weight: Font.Bold
                color: Color.mOnSurface
              }
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 78 * Style.uiScaleRatio
        radius: Style.radiusL
        color: Color.mSurfaceVariant
        border.width: Style.borderS
        border.color: Color.mOutline

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          RowLayout {
            Layout.fillWidth: true

            NText {
              Layout.fillWidth: true
              text: "Token composition"
              font.weight: Font.DemiBold
              color: Color.mOnSurface
            }

            NText {
              text: "Input " + root.compact(root.today.input)
                + "  ·  Cache " + root.compact(root.today.cacheRead)
                + "  ·  Write " + root.compact(root.today.cacheWrite)
                + "  ·  Output " + root.compact(root.today.output)
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 10 * Style.uiScaleRatio
            radius: height / 2
            color: Color.mSurface
            clip: true

            Row {
              anchors.fill: parent

              Rectangle {
                width: parent.width * Number(root.today.input || 0) / Math.max(1, Number(root.today.totalTokens || 0))
                height: parent.height
                color: Color.mPrimary
              }

              Rectangle {
                width: parent.width * Number(root.today.cacheRead || 0) / Math.max(1, Number(root.today.totalTokens || 0))
                height: parent.height
                color: Color.mSecondary
              }

              Rectangle {
                width: parent.width * Number(root.today.cacheWrite || 0) / Math.max(1, Number(root.today.totalTokens || 0))
                height: parent.height
                color: Color.mTertiary
              }

              Rectangle {
                width: parent.width * Number(root.today.output || 0) / Math.max(1, Number(root.today.totalTokens || 0))
                height: parent.height
                color: Color.mOnSurfaceVariant
              }
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Style.radiusL
        color: Color.mSurfaceVariant
        border.width: Style.borderS
        border.color: Color.mOutline

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          RowLayout {
            Layout.fillWidth: true

            NText {
              Layout.fillWidth: true
              text: "Models · last 24 hours"
              pointSize: Style.fontSizeL
              font.weight: Font.Bold
              color: Color.mOnSurface
            }

            NText {
              text: "MODEL  ·  TOKENS  ·  CACHE REUSE  ·  API COST"
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.borderS
            color: Color.mOutline
          }

          Repeater {
            model: root.today.models ? root.today.models.slice(0, 5) : []

            delegate: RowLayout {
              required property var modelData
              Layout.fillWidth: true
              Layout.preferredHeight: 38 * Style.uiScaleRatio
              spacing: Style.marginM

              Rectangle {
                Layout.preferredWidth: 30 * Style.uiScaleRatio
                Layout.preferredHeight: 30 * Style.uiScaleRatio
                radius: Style.radiusS
                color: Color.mSurface
                border.width: Style.borderS
                border.color: Color.mOutline

                Image {
                  anchors.fill: parent
                  anchors.margins: 6 * Style.uiScaleRatio
                  source: Qt.resolvedUrl("../../token-meter/icons/" + (modelData.icon || "ai") + ".svg")
                  fillMode: Image.PreserveAspectFit
                  smooth: true
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                NText {
                  text: (modelData.name || "Unknown") + " · " + (modelData.source || "Unknown source")
                  font.weight: Font.DemiBold
                  color: Color.mOnSurface
                }

                NText {
                  text: modelData.provider || "Unknown provider"
                  pointSize: Style.fontSizeXS
                  color: Color.mOnSurfaceVariant
                }
              }

              NText {
                Layout.preferredWidth: 82 * Style.uiScaleRatio
                horizontalAlignment: Text.AlignRight
                text: root.compact(modelData.totalTokens)
                font.weight: Font.Bold
                color: Color.mOnSurface
              }

              NText {
                Layout.preferredWidth: 68 * Style.uiScaleRatio
                horizontalAlignment: Text.AlignRight
                text: Math.round(Number(modelData.cacheRate || 0) * 100) + "% reused"
                font.weight: Font.DemiBold
                color: Color.mSecondary
              }

              NText {
                Layout.preferredWidth: 74 * Style.uiScaleRatio
                horizontalAlignment: Text.AlignRight
                text: root.money(modelData.cost)
                font.weight: Font.DemiBold
                color: Color.mPrimary
              }
            }
          }

          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 96 * Style.uiScaleRatio
            visible: !root.today.models || root.today.models.length === 0

            Column {
              anchors.centerIn: parent
              width: Math.min(parent.width, 360 * Style.uiScaleRatio)
              spacing: Style.marginS

              NIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                icon: "chart-dots"
                pointSize: Style.fontSizeXL
                color: Color.mOnSurfaceVariant
              }

              NText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "No token activity in the last 24 hours"
                color: Color.mOnSurfaceVariant
              }
            }
          }
        }
      }
    }
  }
}

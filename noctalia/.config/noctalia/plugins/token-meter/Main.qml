import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var pluginApi: null
  property var stats: ({
    periods: {
      today: {
        totalTokens: 0,
        cacheRate: 0,
        cost: 0,
        requests: 0,
        models: []
      }
    }
  })
  property bool busy: false
  readonly property string helperPath: Quickshell.env("HOME") + "/.config/noctalia/token-meter/token-meter.py"

  function refresh() {
    if (busy)
      return;

    busy = true;
    snapshotProcess.exec(["python3", helperPath, "snapshot"]);
  }

  function openDashboard() {
    dashboardProcess.exec(["python3", helperPath, "open"]);
  }

  Process {
    id: snapshotProcess
    stdout: StdioCollector {}

    onExited: function(exitCode) {
      root.busy = false;

      if (exitCode !== 0)
        return;

      try {
        root.stats = JSON.parse(stdout.text);
      } catch (error) {
      }
    }
  }

  Process {
    id: dashboardProcess
  }

  Timer {
    interval: 15000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  IpcHandler {
    target: "plugin:token-meter"

    function refresh() {
      root.refresh();
    }

    function open() {
      root.openDashboard();
    }
  }
}

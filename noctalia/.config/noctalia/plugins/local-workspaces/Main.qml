import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Services.Compositor

Item {
  id: root

  property var pluginApi: null
  property var workspaces: []
  property int focusedId: -1
  property var workspaceData: []
  property var urgentAddresses: []
  property var clientWorkspaceByAddress: ({})
  property bool refreshPending: false

  function refresh() {
    if (workspaceProcess.running || clientProcess.running) {
      refreshPending = true;
      return;
    }

    workspaceProcess.exec(["hyprctl", "workspaces", "-j"]);
  }

  function updateFocusedId() {
    focusedId = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1;
  }

  function pickClient(candidates) {
    let best = null;

    for (const client of candidates)
      if (!best || Number(client.focusHistoryID) < Number(best.focusHistoryID))
        best = client;

    return best;
  }

  function normalizeAddress(value) {
    const address = String(value || "").trim().toLowerCase();

    if (!address)
      return "";

    return address.startsWith("0x") ? address : "0x" + address;
  }

  function markUrgent(value) {
    const address = normalizeAddress(value);

    if (!address || urgentAddresses.includes(address))
      return;

    urgentAddresses = urgentAddresses.concat([address]);
    refreshDebounce.restart();
  }

  function clearUrgentWorkspace(workspaceId) {
    const id = Number(workspaceId);
    urgentAddresses = urgentAddresses.filter(function(address) {
      return clientWorkspaceByAddress[address] !== id;
    });
    workspaces = workspaces.map(function(workspace) {
      return {
        id: workspace.id,
        name: workspace.name,
        appId: workspace.appId,
        urgent: workspace.id === id ? false : workspace.urgent
      };
    });
  }

  function buildModel(clients) {
    updateFocusedId();

    const clientsByAddress = {};
    const clientsByWorkspace = {};
    const workspaceByAddress = {};

    for (const client of clients) {
      const address = normalizeAddress(client.address);
      clientsByAddress[client.address] = client;

      const wsId = client.workspace ? Number(client.workspace.id) : -1;
      workspaceByAddress[address] = wsId;

      if (!clientsByWorkspace[wsId])
        clientsByWorkspace[wsId] = [];

      clientsByWorkspace[wsId].push(client);
    }

    const activeUrgentAddresses = urgentAddresses.filter(function(address) {
      return workspaceByAddress[address] !== undefined
        && workspaceByAddress[address] !== focusedId;
    });
    const urgentWorkspaces = {};

    for (const address of activeUrgentAddresses)
      urgentWorkspaces[workspaceByAddress[address]] = true;

    clientWorkspaceByAddress = workspaceByAddress;
    urgentAddresses = activeUrgentAddresses;

    const next = [];

    for (const workspace of workspaceData) {
      const id = Number(workspace.id);
      // lastwindow остаётся 0x0, пока окно ни разу не получало фокус — так бывает
      // у всего, что открыто через [workspace N silent]
      const client = clientsByAddress[workspace.lastwindow] || pickClient(clientsByWorkspace[id] || []);

      if (id <= 0 || Number(workspace.windows) <= 0 || !client)
        continue;

      next.push({
        id: id,
        name: String(workspace.name || id),
        appId: String(client.class || client.initialClass || "application-x-executable"),
        urgent: urgentWorkspaces[id] === true
      });
    }

    next.sort(function(a, b) {
      return a.id - b.id;
    });

    workspaces = next;
  }

  function finishRefresh() {
    if (!refreshPending)
      return;

    refreshPending = false;
    refreshDebounce.restart();
  }

  function activate(workspaceId) {
    const id = Number(workspaceId);

    if (!Number.isFinite(id))
      return;

    CompositorService.switchToWorkspace({
      idx: id,
      name: String(id)
    });
  }

  function switchByOffset(offset) {
    if (workspaces.length < 2)
      return;

    let current = workspaces.findIndex(function(workspace) {
      return workspace.id === focusedId;
    });

    if (current < 0)
      current = 0;

    let next = (current + offset) % workspaces.length;

    if (next < 0)
      next = workspaces.length - 1;

    activate(workspaces[next].id);
  }

  Process {
    id: workspaceProcess
    stdout: StdioCollector {}

    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.finishRefresh();
        return;
      }

      try {
        root.workspaceData = JSON.parse(stdout.text);
        clientProcess.exec(["hyprctl", "clients", "-j"]);
      } catch (error) {
        root.finishRefresh();
      }
    }
  }

  Process {
    id: clientProcess
    stdout: StdioCollector {}

    onExited: function(exitCode) {
      if (exitCode === 0) {
        try {
          root.buildModel(JSON.parse(stdout.text));
        } catch (error) {
        }
      }

      root.finishRefresh();
    }
  }

  Timer {
    id: refreshDebounce
    interval: 50
    repeat: false
    onTriggered: root.refresh()
  }

  // Hyprland events can be missed while several applications start at once.
  // Periodically reconcile the complete occupied-workspace list as a fallback.
  Timer {
    interval: 2000
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event.name === "urgent")
        root.markUrgent(event.data);

      refreshDebounce.restart();
    }

    function onFocusedWorkspaceChanged() {
      root.updateFocusedId();
      root.clearUrgentWorkspace(root.focusedId);
      refreshDebounce.restart();
    }
  }

  IpcHandler {
    target: "plugin:local-workspaces"

    function refresh() {
      root.refresh();
    }
  }

  Component.onCompleted: root.refresh()
}

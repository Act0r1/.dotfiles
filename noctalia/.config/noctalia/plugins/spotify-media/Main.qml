import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Services.Media
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null

  readonly property bool isSpotify: {
    const player = MediaService.currentPlayer;
    if (!player)
      return false;

    const identity = String(player.identity || "").toLowerCase();
    const dbusName = String(player.dbusName || "").toLowerCase();
    return identity.includes("spotify") || dbusName.includes("spotify");
  }

  function likeTrack() {
    if (!root.isSpotify) {
      ToastService.showError("The active player is not Spotify");
      return;
    }
    if (likeProcess.running)
      return;

    likeProcess.command = [
      "hyprctl",
      "dispatch",
      "hl.dsp.send_shortcut({ mods = \"ALT SHIFT\", key = \"B\", window = \"class:Spotify\" })"
    ];
    likeProcess.running = true;
  }

  function dislikeTrack() {
    if (!root.isSpotify) {
      ToastService.showError("The active player is not Spotify");
      return;
    }
    if (dislikeProcess.running)
      return;

    dislikeProcess.command = [
      "hyprctl",
      "dispatch",
      "hl.dsp.send_shortcut({ mods = \"CTRL SHIFT\", key = \"BackSpace\", window = \"class:Spotify\" })"
    ];
    dislikeProcess.running = true;
  }

  Process {
    id: likeProcess

    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0)
        ToastService.showNotice("Spotify Like toggled");
      else
        ToastService.showError("Could not toggle Spotify Like");
    }
  }

  Process {
    id: dislikeProcess

    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0)
        ToastService.showNotice("Spotify track disliked");
      else
        ToastService.showError("Could not dislike Spotify track");
    }
  }
}

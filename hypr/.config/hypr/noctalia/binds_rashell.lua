local mainMod = "SUPER"
local home = os.getenv("HOME")
local ipc = home .. "/.local/opt/rashell-runtime/quickshell -c rashell ipc call rashell "

hl.bind(mainMod .. "+Space", hl.dsp.exec_cmd(ipc .. "launcherToggle"))
hl.bind(mainMod .. "+S", hl.dsp.exec_cmd(ipc .. "controlCenterToggle"))
hl.bind(mainMod .. "+comma", hl.dsp.exec_cmd(ipc .. "audioPanelToggle"))

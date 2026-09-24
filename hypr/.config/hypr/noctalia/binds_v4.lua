local ipc = "qs -c noctalia-shell ipc call "

hl.bind("SUPER+Space", hl.dsp.exec_cmd(ipc .. "launcher toggle"))

{ config, ... }:
let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  link = config.lib.file.mkOutOfStoreSymlink;
in
{
  home.file = {
    ".claude/CLAUDE.md".source = link "${dotfiles}/claude/.claude/CLAUDE.md";
    ".codex/AGENTS.md".source = link "${dotfiles}/codex/.codex/AGENTS.md";
    ".pi/agent/AGENTS.md".source = link "${dotfiles}/pi/.pi/agent/AGENTS.md";
    ".zshenv".source = link "${dotfiles}/zsh/.zshenv";
    ".zprofile".source = link "${dotfiles}/zsh/.zprofile";
    ".zshrc".source = link "${dotfiles}/zsh/.zshrc";
    ".tmux.conf".source = link "${dotfiles}/tmux/.tmux.conf";
    "tmux-change-session-path.sh".source = link "${dotfiles}/tmux/tmux-change-session-path.sh";
    "scripts".source = link "${dotfiles}/tmux/scripts";
  };

  xdg.configFile = {
    "fish".source = link "${dotfiles}/fish/.config/fish";
    "ghostty".source = link "${dotfiles}/ghostty/.config/ghostty";
    "nvim".source = link "${dotfiles}/nvim/.config/nvim";
    "starship".source = link "${dotfiles}/starship/.config/starship";
    "zed".source = link "${dotfiles}/zed/.config/zed";
  };
}

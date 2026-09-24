{ lib, pkgs, ... }:
let
  neovimUnwrapped = pkgs.neovim-unwrapped.overrideAttrs (finalAttrs: previousAttrs: {
    version = "0.12.5";
    src = pkgs.fetchFromGitHub {
      owner = "neovim";
      repo = "neovim";
      tag = "v${finalAttrs.version}";
      hash = "sha256-dpu2kncpm+2k+XR7qOEi4KeEy9a1E6X7kjf3s4AbcSo=";
    };
    preCheck = (previousAttrs.preCheck or "") + ''
      export XDG_RUNTIME_DIR="$NIX_BUILD_TOP/tests"
      mkdir -p "$XDG_RUNTIME_DIR"
    '';
  });
  neovim = pkgs.wrapNeovim neovimUnwrapped { };
in
{
  home.packages =
    (with pkgs; [
      nerd-fonts.comic-shanns-mono
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only

      bat
      age
      biome
      btop
      bun
      curl
      delta
      direnv
      eza
      fastfetch
      fd
      fish
      fzf
      gh
      gnutar
      jq
      just
      lazydocker
      lazygit
      neovim
      nodejs
      oh-my-zsh
      pnpm
      python3
      ripgrep
      rustup
      starship
      stow
      tmux
      unzip
      uv
      wget
      yazi
      zip
      zoxide
      zstd
      zsh
      zsh-autosuggestions
      zsh-syntax-highlighting

      basedpyright
      astro-language-server
      clang-tools
      docker-compose-language-service
      gopls
      lua-language-server
      marksman
      nil
      nixfmt
      ocamlPackages.ocaml-lsp
      postgres-language-server
      prettier
      ruff
      (lib.hiPrio rust-analyzer)
      (lib.hiPrio rustfmt)
      stylua
      tailwindcss-language-server
      taplo
      terraform-ls
      typescript-language-server
      vscode-langservers-extracted
      zls
    ])
    ++ lib.optionals pkgs.stdenv.isLinux (
      with pkgs;
      [
        gcc
        ghostty
        libsecret
        lsof
        zed-editor
      ]
    );

  home.sessionVariables = {
    NVIM_NIX_MANAGED = "1";
    ZSH = "${pkgs.oh-my-zsh}/share/oh-my-zsh";
    ZSH_AUTOSUGGESTIONS = "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh";
    ZSH_SYNTAX_HIGHLIGHTING = "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";
  };
}

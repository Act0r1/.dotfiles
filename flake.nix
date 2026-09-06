{
  description = "Portable Home Manager environment for Linux and macOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-darwin-x86_64.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager-darwin-x86_64 = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin-x86_64";
    };

    inir = {
      url = "github:snowarch/inir/dcba34ee124acb5a191c88b2e1952006fa5afb2f";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia-v4 = {
      url = "github:noctalia-dev/noctalia/legacy-v4";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia-v5.url = "github:noctalia-dev/noctalia";
  };

  outputs =
    inputs@{
      nixpkgs,
      nixpkgs-darwin-x86_64,
      home-manager,
      home-manager-darwin-x86_64,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      profilesForSystem = {
        x86_64-linux = [
          "desktop"
          "desktop-hyprland"
        ];
        aarch64-linux = [ "linux-aarch64" ];
        x86_64-darwin = [ "darwin-x86_64" ];
        aarch64-darwin = [ "darwin-aarch64" ];
      };
      pkgsFor =
        system:
        import (if system == "x86_64-darwin" then nixpkgs-darwin-x86_64 else nixpkgs) {
          inherit system;
          config.allowUnfree = true;
        };
      homeManagerFor =
        system: if system == "x86_64-darwin" then home-manager-darwin-x86_64 else home-manager;
      homeManagerPackage =
        system:
        let
          homeManager = homeManagerFor system;
        in
        (pkgsFor system).callPackage "${homeManager}/home-manager" { path = "${homeManager}"; };
      mkHome =
        {
          system,
          hostModule,
          username ? "yeager",
        }:
        (homeManagerFor system).lib.homeManagerConfiguration {
          pkgs = pkgsFor system;
          extraSpecialArgs = { inherit inputs username; };
          modules = [
            ./home
            hostModule
          ];
        };
      mkApplyPackage =
        system:
        let
          pkgs = pkgsFor system;
          profiles = profilesForSystem.${system};
          defaultProfile = builtins.head profiles;
          allowedProfiles = builtins.concatStringsSep " " profiles;
        in
        pkgs.writeShellApplication {
          name = "apply-dotfiles";
          runtimeInputs = [ (homeManagerPackage system) ];
          text = ''
            dotfiles="$HOME/.dotfiles"
            profile="''${1:-${defaultProfile}}"

            if [[ ! -f "$dotfiles/flake.nix" ]]; then
              printf 'Dotfiles repository not found at %s\n' "$dotfiles" >&2
              printf 'Clone the repository to ~/.dotfiles first.\n' >&2
              exit 1
            fi

            if [[ $# -gt 1 ]] || [[ " ${allowedProfiles} " != *" $profile "* ]]; then
              printf 'Usage: apply-dotfiles [${builtins.concatStringsSep "|" profiles}]\n' >&2
              exit 2
            fi

            exec home-manager switch \
              --flake "$dotfiles#$profile" \
              -b hm-backup
          '';
        };
    in
    {
      homeConfigurations = {
        desktop = mkHome {
          system = "x86_64-linux";
          hostModule = ./hosts/desktop.nix;
        };

        desktop-hyprland = mkHome {
          system = "x86_64-linux";
          hostModule = ./hosts/desktop-hyprland.nix;
        };

        linux-aarch64 = mkHome {
          system = "aarch64-linux";
          hostModule = ./hosts/linux-aarch64.nix;
        };

        darwin-x86_64 = mkHome {
          system = "x86_64-darwin";
          hostModule = ./hosts/darwin.nix;
        };

        darwin-aarch64 = mkHome {
          system = "aarch64-darwin";
          hostModule = ./hosts/darwin.nix;
        };
      };

      packages = forAllSystems (system: {
        home-manager = homeManagerPackage system;
      });

      apps = forAllSystems (
        system:
        let
          applyPackage = mkApplyPackage system;
          app = {
            type = "app";
            program = "${applyPackage}/bin/apply-dotfiles";
            meta.description = "Apply the matching Home Manager profile";
          };
        in
        {
          default = app;
          apply = app;
        }
      );

      formatter = forAllSystems (system: (pkgsFor system).nixfmt);
    };
}

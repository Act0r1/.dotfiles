default:
    @just --list

check:
    nix --extra-experimental-features 'nix-command flakes' flake check --all-systems

build profile="desktop":
    nix --extra-experimental-features 'nix-command flakes' build ".#homeConfigurations.{{profile}}.activationPackage" --no-link

apply:
    bash bootstrap/apply.sh

switch:
    bash bootstrap/apply.sh

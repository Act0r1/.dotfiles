{ pkgs, ... }:
{
  programs.git = {
    enable = true;
    package = pkgs.gitFull;
    ignores = [
      "**/.claude/settings.local.json"
      "**/.DS_Store"
    ];
    settings = {
      user = {
        name = "actor";
        email = "gizatullininsaf25@gmail.com";
      };
      alias.st = "status";
      core = {
        editor = "nvim";
        pager = "delta";
      };
      credential.helper = if pkgs.stdenv.isDarwin then "osxkeychain" else "libsecret";
      delta = {
        navigate = true;
        side-by-side = true;
      };
      diff.tool = "nvimdiff";
      init.defaultBranch = "master";
      interactive.diffFilter = "delta --color-only";
      merge.conflictStyle = "zdiff3";
    };
  };
}

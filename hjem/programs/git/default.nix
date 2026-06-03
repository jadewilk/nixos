{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.localDef.programs.git;
in
{
  options.localDef.programs.git = {
    enable = lib.mkEnableOption "git";
    name = lib.mkOption {
      type = lib.types.str;
      default = "Jade Wilk";
    };
    email = lib.mkOption {
      type = lib.types.str;
      default = "p.wilk@student.reading.ac.uk";
    };
    signingKey = lib.mkOption {
      type = lib.types.str;
      default = "/home/philip/.ssh/gitKey";
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.config.files."git/config" = {
      generator = lib.generators.toGitINI;
      value = {
        alias = {
          pl = "log --graph --abbrev-commit --decorate --stat";
          dh = "diff HEAD";
          dhp = "diff HEAD~";
          push-fwl = "push --force-with-lease";
          rhp = "reset HEAD~";
          rhph = "reset HEAD~ --hard";
          rhh = "reset HEAD --hard";
        };
        commit = {
          gpgSign = true;
        };
        core = {
          editor = lib.getExe pkgs.helix;
          pager = "${lib.getExe pkgs.diff-so-fancy} | ${lib.getExe pkgs.less} \'--tabs=4\' -RFX";
        };
        gpg = {
          format = "ssh";
        };
        "gpg \"openpgp\"" = {
          programs = lib.getExe pkgs.gnupg;
        };
        init = {
          defaultBranch = "main";
        };
        interactive = {
          diffFilters = "${lib.getExe pkgs.diff-so-fancy} --patch";
        };
        pull = {
          rebase = true;
        };
        push = {
          autoSetupRemote = true;
        };
        rerere = {
          enabled = true;
        };
        tag = {
          gpgSign = true;
        };
        user = {
          inherit (cfg) name email signingKey;
        };
      };
    };
  };
}

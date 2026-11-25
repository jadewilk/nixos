{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.localDef.programs.gh.enable = lib.mkEnableOption "gh";
  options.localDef.programs.gh.interactive = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };
  options.localDef.programs.gh.user = lib.mkOption {
    type = lib.types.str;
    default = "jadewilk";
  };

  config = lib.mkIf config.localDef.programs.gh.enable {
    packages = with pkgs; [ gh ];

    xdg.config.files."gh/config.yml" = {
      generator = lib.generators.toYAML { };
      value = {
        version = "1";
        aliases = { };
        editor = lib.getExe pkgs.kakoune;
        git_protocol = "ssh";
      };
    };
    xdg.config.files."gh/hosts.yml" = lib.mkIf config.localDef.programs.gh.interactive {
      generator = lib.generators.toYAML { };
      value = {
        "github.com" = {
          git_protocol = "ssh";
          users.${config.localDef.programs.gh.user} = { };
          user = config.localDef.programs.gh.user;
        };
      };
    };
  };
}

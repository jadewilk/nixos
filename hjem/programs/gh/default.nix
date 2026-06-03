{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.localDef.programs.gh.enable = lib.mkEnableOption "gh";

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
    xdg.config.files."gh/hosts.yml" = {
      generator = lib.generators.toYAML { };
      value = {
        "github.com" = {
          git_protocol = "ssh";
          users.jadewilk = { };
          user = "jadewilk";
        };
      };
    };
  };
}

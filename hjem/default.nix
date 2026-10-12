{
  lib,
  inputs,
  config,
  ...
}:
let
  commonLocalDef = {
    bottom.enable = true;
    bat.enable = true;
    carapace.enable = true;
    git.enable = true;
    ssh.enable = true;
    nix.enable = true;
    direnv.enable = true;
    eza.enable = true;
    skim.enable = true;
    zoxide.enable = true;
    helix.enable = true;
    starship.enable = true;
    gh.enable = true;
    gh-dash.enable = true;
    kakoune.enable = true;
    fish.enable = true;
  };
in
{
  options.hjem.interactive = lib.mkEnableOption "interactive tty modules";

  config = {
    hjem = {
      clobberByDefault = true;
      extraModules = lib.filesystem.listFilesRecursive ./programs;
      specialArgs = { inherit inputs; };
      users = {
        philip = lib.mkIf (config.flakeConfig.environment.primaryHomeManagedUser == "philip") {
          directory = "/home/philip";
          user = "philip";
          localDef.programs = lib.mergeAttrs (
            if config.hjem.interactive then
              {
                matlab.enable = true;
                openldap.enable = true;
                easyeffects.enable = true;
                fcitx.enable = true;
                kitty.enable = true;
                fuzzel.enable = true;
                # nix-index.enable = true;
                # nix-index-database / comma
              }
            else
              { }
          ) commonLocalDef;
        };
        root = {
          directory = "/root";
          user = "root";
          localDef.programs = commonLocalDef;
        };
        wslphilip = lib.mkIf (config.flakeConfig.environment.primaryHomeManagedUser == "wslphilip") {
          directory = "/home/wslphilip";
          user = "wslphilip";
          localDef.programs = commonLocalDef;
        };
        pwilk = lib.mkIf (config.flakeConfig.environment.primaryHomeManagedUser == "pwilk") {
          directory = "/home/pwilk";
          user = "pwilk";
          localDef.programs = commonLocalDef;
        };
      };
    };
  };
}

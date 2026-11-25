{
  lib,
  inputs,
  config,
  ...
}:
let
  interactive = config.hjem.interactive;

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
    gh = {
      enable = true;
      inherit interactive;
    };
    gh-dash.enable = true;
    kakoune.enable = true;
    fish.enable = true;

    openldap.enable = interactive;
    easyeffects.enable = interactive;
    fcitx.enable = interactive;
    kitty.enable = interactive;
    fuzzel.enable = interactive;
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
          localDef.programs = commonLocalDef;
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

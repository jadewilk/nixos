{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.localDef.programs.fish;

  mkPluginConf = pluginSrc: ''
    set -l plugin_dir ${pluginSrc}

    # Set paths to import plugin components
    if test -d $plugin_dir/functions
      set fish_function_path $fish_function_path[1] $plugin_dir/functions $fish_function_path[2..-1]
    end

    if test -d $plugin_dir/completions
      set fish_complete_path $fish_complete_path[1] $plugin_dir/completions $fish_complete_path[2..-1]
    end

    # Source initialization code if it exists.
    if test -d $plugin_dir/conf.d
      for f in $plugin_dir/conf.d/*.fish
        source $f
      end
    end

    if test -f $plugin_dir/key_bindings.fish
      source $plugin_dir/key_bindings.fish
    end

    if test -f $plugin_dir/init.fish
      source $plugin_dir/init.fish
    end
  '';

  translatedSessionVariables = pkgs.runCommandLocal "session-vars.fish" { } ''
    (echo "function setup_session_vars;"
    ${pkgs.buildPackages.babelfish}/bin/babelfish \
    <${config.environment.loadEnv}
    echo "end"
    echo "setup_session_vars") > $out
  '';
in
{
  options.localDef.programs.fish = {
    enable = lib.mkEnableOption "fish";
    interactiveInit = lib.mkOption {
      type = lib.types.lines;
      default = "";
    };
    loginInit = lib.mkOption {
      type = lib.types.lines;
      default = "";
    };
    shellInit = lib.mkOption {
      type = lib.types.lines;
      default = "";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = with pkgs; [
      fish
      grc
    ];

    xdg.config.files."fish/config.fish".text = ''
      set fish_greeting

      # stolen from hm
      set -q __fish_config_sourced; and exit
      set -g __fish_config_sourced 1

      fish_config theme choose "catppuccin-frappe" --color-theme=light

      source ${translatedSessionVariables}

      ${cfg.shellInit}

      status is-login; and begin
        ${cfg.loginInit}
      end

      status is-interactive; and begin
        ${cfg.interactiveInit}
      end
    '';

    xdg.config.files."fish/themes/catppuccin-frappe.theme".source = "${
      inputs.catppuccin.packages.${pkgs.stdenv.hostPlatform.system}.fish
    }/catppuccin-frappe.theme";

    xdg.config.files."fish/conf.d/plugin-grc".text = mkPluginConf pkgs.fishPlugins.grc.src;
  };
}

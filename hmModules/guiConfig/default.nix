{
  pkgs,
  ...
}:
{

  home = {
    packages = with pkgs; [
      (catppuccin.override {
        accent = "peach";
        variant = "latte";
      })
      adw-gtk3
      qadwaitadecorations
      qadwaitadecorations-qt6
    ];
    sessionVariables = {
      QT_QPA_PLATFORMTHEME = "gtk3";
      QT_WAYLAND_DECORATION = "adwaita";
    };
  };

  gtk.gtk3.extraConfig.application-prefer-dark-theme = false;

  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };
    "org/gnome/desktop/wm/preferences" = {
      button-layout = ":menu,close";
    };
    "org/gnome/desktop/interface" = {
      accent-color = "pink";
      gtk-theme = "Adwaita";
      color-scheme = "prefer-light";
      font-name = "Manrope 13";
    };
  };

  catppuccin = {
    cursors = {
      enable = true;
      accent = "peach";
    };
    sources.whiskers = pkgs.catppuccin-whiskers;
  };
}

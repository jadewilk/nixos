{
  ...
}:
{
  nixpkgs.overlays = [
    # add cpu monitoring option
    (import ./hddfancontrol)

    (final: prev: {
      proj = prev.proj.overrideAttrs {
        version = "9.7.1";
        src = prev.fetchFromGitHub {
          owner = "OSGeo";
          repo = "PROJ";
          tag = "9.7.1";
          hash = "sha256-xXtqbLPS2Hu9gC06b72HDjnNRh4m0ism97hP8FFYOMo=";
        };
      };
    })

    (import ./chip-ota-provider-app)

    (final: prev: {
      python313 = prev.python313.override {
        packageOverrides = pFinal: pPrev: {
          mlxtend = prev.python313.pkgs.callPackage ./mlxtend { };
        };
      };
      python314 = prev.python314.override {
        packageOverrides = pFinal: pPrev: {
          mlxtend = prev.python314.pkgs.callPackage ./mlxtend { };
        };
      };
    })
  ];
}

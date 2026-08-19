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
  ];
}

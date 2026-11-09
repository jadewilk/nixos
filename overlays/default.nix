{
  ...
}:
{
  nixpkgs.overlays = [
    (final: prev: {
      ripunzip = prev.callPackage ./ripunzip/package.nix { };
    })
  ];
}

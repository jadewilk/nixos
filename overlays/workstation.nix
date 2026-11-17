{
  ...
}:
{
  nixpkgs.overlays = [
    (import ./marvisclient-linux)

    (final: prev: {
      intellij-idea = prev.callPackage ./intellij-idea/package.nix { };
    })
  ];
}

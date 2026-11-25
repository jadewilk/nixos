{
  ...
}:
{
  nixpkgs.overlays = [
    (import ./marvisclient-linux)

    (final: prev: {
      jetbrains-jdk = prev.callPackage ./jetbrains-jdk { };
      intellij-idea = prev.callPackage ./intellij-idea/package.nix { };
    })
  ];
}

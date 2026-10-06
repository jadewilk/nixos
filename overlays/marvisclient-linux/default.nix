(final: prev: {
  marvisclient-linux-unwrapped = prev.callPackage ./marvisclient-linux-unwrapped.nix { };
  marvisclient-linux = prev.callPackage ./marvisclient-linux.nix { };
})

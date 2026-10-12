{
  ...
}:
{
  nix.buildMachines = [
    {
      hostName = "nixbuilder@rdg.uk.region.fogbox.uk";
      system = "x86_64-linux";
      protocol = "ssh-ng";
      maxJobs = 8;
      speedFactor = 5;
      supportedFeatures = [
        "nixos-test"
        "benchmark"
        "big-parallel"
        "kvm"
      ];
      mandatoryFeatures = [ ];
    }
    {
      hostName = "nixbuilder@sou.uk.region.fogbox.uk";
      system = "x86_64-linux";
      protocol = "ssh-ng";
      maxJobs = 6;
      speedFactor = 2;
      supportedFeatures = [
        "nixos-test"
        "benchmark"
        "big-parallel"
        "kvm"
      ];
      mandatoryFeatures = [ ];
    }
  ];

  nix.distributedBuilds = true;
  nix.settings.builders-use-substitutes = true;
}

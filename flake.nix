{
  description = "system definitions";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    make-shell.url = "github:nicknovitski/make-shell";
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-matlab = {
      url = "gitlab:doronbehar/nix-matlab";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    buildbot-nix = {
      url = "github:Mic92/buildbot-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-dns = {
      url = "github:Janik-Haag/nixos-dns";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hjem = {
      url = "github:feel-co/hjem";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, ... }@inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      top@{
        config,
        self,
        withSystem,
        moduleWithSystem,
        ...
      }:
      {
        imports = [
          inputs.treefmt-nix.flakeModule
          inputs.make-shell.flakeModules.default
          inputs.home-manager.flakeModules.home-manager
        ];

        systems = [
          "x86_64-linux"
        ];

        flake =
          {
            lib,
            pkgs,
            ...
          }:
          {
            nixosConfigurations = withSystem "x86_64-linux" (
              {
                pkgs,
                system,
                ...
              }:
              let
                mkSystemFactory =
                  classModules: hostModule:
                  inputs.nixpkgs.lib.nixosSystem {
                    inherit system;
                    modules = classModules ++ [
                      ./overlays
                      ./osModules
                      ./hjem
                      inputs.agenix.nixosModules.default
                      inputs.home-manager.nixosModules.default
                      inputs.hjem.nixosModules.default
                      (
                        { ... }:
                        {
                          networking.hostName = lib.mkDefault (builtins.baseNameOf hostModule);
                        }
                      )
                      hostModule
                    ];
                    specialArgs = { inherit inputs; };
                  };

                mkWorkstationSystem = mkSystemFactory [
                  ./overlays/workstation.nix
                  ./osModules/workstation.nix
                  inputs.lanzaboote.nixosModules.lanzaboote
                ];

                mkWslSystem = mkSystemFactory [
                  ./overlays/workstation.nix
                  ./osModules/wsl.nix
                  inputs.nixos-wsl.nixosModules.default
                ];

                mkHomelabSystem = mkSystemFactory [
                  ./overlays/homelab.nix
                  ./osModules/homelab.nix
                  ./osModules/routing.nix
                  inputs.buildbot-nix.nixosModules.buildbot-master
                  inputs.buildbot-nix.nixosModules.buildbot-worker
                  inputs.nixos-dns.nixosModules.dns
                ];

              in
              (lib.mkMerge [
                (lib.attrsets.genAttrs [
                  "prime"
                  "probook"
                  "mini"
                  #"nixosvmtest"
                ] (hostname: mkWorkstationSystem ./infra/${hostname}))
                (lib.attrsets.genAttrs [
                  "wslphilip"
                  "pwilk"
                ] (hostname: mkWslSystem ./infra/${hostname}))
                (lib.attrsets.genAttrs [
                  "sou"
                  "rdg"
                ] (hostname: mkHomelabSystem ./infra/${hostname}))
              ])
            );
          };

        perSystem =
          {
            config,
            pkgs,
            lib,
            system,
            self',
            ...
          }:
          {
            # devshells
            make-shells.default = {
              packages = with pkgs; [
                nixfmt
                nil
                nix-tree
              ];
            };
            # Formatting for all the things
            treefmt =
              { ... }:
              {
                projectRootFile = "flake.nix";

                programs = {
                  nixfmt.enable = true;
                  jsonfmt.enable = true;
                  mdformat.enable = true;
                };

                settings.global.excludes = [
                  "*.age"
                  "*.ldif"
                  "*.envrc"
                  "*.css"
                ];
              };

            packages =
              let
                dnsGenerators = inputs.nixos-dns.utils.generate pkgs;
                generateZoneAttrs = inputs.nixos-dns.utils.octodns.generateZoneAttrs;
                # Using these is suboptimal atm
                # ideally can we make this consumable from a gh action/bot or something that would be really cool
                # but right now
                /*
                  sudo cat /run/agenix/octodns_desec_secret | source
                  DESEC_TOKEN=$DESEC_TOKEN octodns-sync --config-file=$(nix build .#octodns --print-out-paths)
                */
              in
              {
                zoneFiles = dnsGenerators.zoneFiles {
                  inherit (self) nixosConfigurations;
                  extraConfig = import ./dns;
                };
                octodns = dnsGenerators.octodnsConfig {
                  dnsConfig = {
                    inherit (self) nixosConfigurations;
                    extraConfig = import ./dns;
                  };
                  config.providers.desec = {
                    class = "octodns_desec.DesecProvider";
                    token = "env/DESEC_TOKEN";
                  };
                  zones."fogbox.uk." = generateZoneAttrs [ "desec" ];
                  zones."jadewilk.uk." = generateZoneAttrs [ "desec" ];
                };
              };

            checks = # nixosConfigurations.machine -> nixosConfigurations-machine
              let
                nixosMachines = (
                  lib.filterAttrs (lib.const (deriv: deriv.system == system)) (
                    (lib.mapAttrs' (
                      name: value: lib.nameValuePair "nixosConfigurations-${name}" value.config.system.build.toplevel
                    ) self.nixosConfigurations)
                  )
                );
                blacklistPackages = [
                  "install-iso"
                  "nspawn-template"
                  "netboot-pixie-core"
                  "netboot"
                ];
                packages = lib.mapAttrs' (n: lib.nameValuePair "package-${n}") (
                  lib.filterAttrs (n: _v: !(builtins.elem n blacklistPackages)) self'.packages
                );
                devShells = lib.mapAttrs' (n: lib.nameValuePair "devShell-${n}") self'.devShells;
              in
              nixosMachines // packages // devShells;
          };
      }
    );
}

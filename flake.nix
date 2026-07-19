{
  description = "NixOS + Hyprland setup inspired by an XFCE/Xubuntu workflow";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland.url = "github:hyprwm/Hyprland";
    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix.url = "github:numtide/treefmt-nix";
    private = {
      url = "path:./private";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      treefmt-nix,
      ...
    }:
    let
      username = "leo";
      defaultSystem = "x86_64-linux";
      supportedSystems = [
        defaultSystem
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      hosts = {
        nixos = {
          system = defaultSystem;
          systemModules = [
            ./hosts/nixos/configuration.nix
            inputs.private.nixosModules.default
          ];
          homeModules = [
            ./home/${username}/base.nix
            ./home/${username}/laptop.nix
            inputs.private.homeManagerModules.default
          ];
        };

        red = {
          system = defaultSystem;
          systemModules = [
            ./hosts/red/configuration.nix
          ];
          homeModules = [
            ./home/${username}/base.nix
            ./home/${username}/server.nix
          ];
        };

        black = {
          system = defaultSystem;
          systemModules = [
            ./hosts/black/configuration.nix
          ];
          homeModules = [
            ./home/${username}/base.nix
            ./home/${username}/server.nix
          ];
        };

        blue = {
          system = defaultSystem;
          systemModules = [
            ./hosts/blue/configuration.nix
          ];
          homeModules = [
            ./home/${username}/base.nix
            ./home/${username}/server.nix
          ];
        };

        raspberrypi = {
          system = "aarch64-linux";
          systemModules = [
            ./hosts/raspberrypi/configuration.nix
          ];
          homeModules = [
            ./home/${username}/kiosk.nix
          ];
        };
      };

      mkHost =
        hostname:
        {
          system ? defaultSystem,
          systemModules,
          homeModules ? [ ./home/${username}/base.nix ],
        }:
        nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs username hostname;
            inherit (inputs) nixos-raspberrypi;
          };
          modules = [
            { nixpkgs.hostPlatform = system; }
          ]
          ++ systemModules
          ++ [
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;

              home-manager.extraSpecialArgs = {
                inherit inputs username hostname;
              };

              home-manager.users.${username} = {
                imports = homeModules;
              };
            }
          ];
        };

      pkgsFor = system: import nixpkgs { inherit system; };
      treefmtFor = system: treefmt-nix.lib.evalModule (pkgsFor system) ./treefmt.nix;
    in
    {
      formatter = forAllSystems (system: (treefmtFor system).config.build.wrapper);
      nixosConfigurations = nixpkgs.lib.mapAttrs mkHost hosts;
    };
}

{
  description = "Nix support for whisper.cpp";

  inputs = {
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    import-tree.url = "github:vic/import-tree";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # Excludes x86_64-darwin.
    systems.url = "github:ink-splatters/nix-systems";
  };

  nixConfig = {
    extra-substituters = [
      "https://aarch64-darwin.cachix.org"
    ];
    extra-trusted-public-keys = [
      "aarch64-darwin.cachix.org-1:mEz8A1jcJveehs/ZbZUEjXZ65Aukk9bg2kmb0zL9XDA="
    ];
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} (let
      importTree = inputs.import-tree;
      systems = import inputs.systems;
      flakeModules.default = import ./nix {inherit importTree;};
    in {
      imports = [
        flakeModules.default
        flake-parts.flakeModules.partitions
      ];

      config = {
        inherit systems;

        partitionedAttrs = {
          apps = "dev";
          checks = "dev";
          devShells = "dev";
          formatter = "dev";
        };
        partitions.dev = let
          dev = import ./nix/dev {inherit importTree;};
        in {
          extraInputsFlake = ./nix/dev;
          module.imports = [dev];
        };

        version = "1.9.1-unmerged-prs.20260803";
        src = builtins.path {
          path = ./.;
          name = "whisper-cpp";
        };

        flake = {inherit flakeModules;};
      };
    });
}

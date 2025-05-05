# oxcaml-overlay

An overlay to use oxcaml in nixpkgs.

## How to use this?

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    # Add this flake input
    oxcaml-overlay.url = "github:emillon/oxcaml-overlay";
    oxcaml-overlay.inputs.nixpkgs.follows = "nixpkgs";
    oxcaml-overlay.inputs.flake-utils.follows = "flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils, oxcaml-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      # Set up pkgs as nixpkgs + this overlay
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            oxcaml-overlay.overlays."${system}".default
          ];
        };
      in
      {
        # Define your package as usual
        packages.default = pkgs.ocamlPackages.buildDunePackage {
          pname = "oxcaml-overlay-tests";
          version = "n/a";
          src = ./.;
          propagatedBuildInputs =
            with pkgs.ocamlPackages;
            [
              base
            ];
        };
        # Add outputs, devshell, formatter, etc
        # ...
      }
    );
}
```

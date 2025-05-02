{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils }:
    let oxcaml-overlay = import ./overlay.nix; in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            oxcaml-overlay
          ];
        };
      in
      {
        formatter = pkgs.nixpkgs-fmt;
        packages.default = pkgs.ocamlPackages.buildDunePackage {
          pname = "oxcaml-tests";
          version = "n/a";
          propagatedBuildInputs =
            with pkgs.ocamlPackages;
            [
              base
            ];
        };
        devShells.default = pkgs.mkShell {
          inputsFrom = [ self.packages."${system}".default ];
          nativeBuildInputs =
            with pkgs.ocamlPackages;
            [
            ];
        };
      });
}

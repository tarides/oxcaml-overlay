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
        overlays.default = oxcaml-overlay;
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
        devShells.default = pkgs.mkShell {
          inputsFrom = [ self.packages."${system}".default ];
          nativeBuildInputs =
            with pkgs.ocamlPackages;
            [
              merlin
              ocamlformat_0_26_2_jst
            ];
        };
      });
}

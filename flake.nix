{
  description = "Promote GitHub Actions artifacts to a GitHub Release as tar.gz";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        promote-release = pkgs.writeShellApplication {
          name = "promote-release";

          runtimeInputs = with pkgs; [
            gh
            gnutar
            gzip
            unzip
            coreutils
            findutils
            gnugrep
            bash
          ];

          text = builtins.readFile ./promote-release.sh;
        };
      in
      {
        packages = {
          default = promote-release;
          promote-release = promote-release;
        };

        apps.default = {
          type = "app";
          program = "${promote-release}/bin/promote-release";
        };
      }
    );
}

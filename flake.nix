{
  description = "Custom Haskell static site generator";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ]
      (system:
        let
          pkgs = import nixpkgs { inherit system; };
          hpkgs = pkgs.haskellPackages;
          ssg = hpkgs.callCabal2nix "ssg" ./. { };
        in {
          packages.default = ssg;

          apps.default = {
            type = "app";
            program = "${ssg}/bin/ssg";
          };

          devShells.default = hpkgs.shellFor {
            packages = p: [ ssg ];
            buildInputs = [
              hpkgs.cabal-install
              hpkgs.haskell-language-server
              hpkgs.ghcid
              hpkgs.ormolu
              pkgs.git
              pkgs.pagefind
              pkgs.nodejs_20
              pkgs.esbuild
              (pkgs.python3.withPackages (ps: with ps; [
                numpy
                scipy
                pandas
                scikit-learn
              ]))
            ];
            shellHook = ''
              echo ""
              echo "  SSG dev environment"
              echo "  cabal run ssg -- build          build site + search index"
              echo "  cabal run ssg -- watch          watch & serve on localhost:8000"
              echo "  cabal run ssg -- watch --search watch with search index rebuilds"
              echo "  cabal run ssg -- clean          clean build artifacts"
              echo ""
              [[ $- == *i* ]] && exec zsh
            '';
          };
        });
}

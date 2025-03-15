{
  description = "Batch download from libgen";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };
  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      packages.${system}.default = pkgs.writeShellApplication {
        name = "libgen_dl";
        runtimeInputs = with pkgs; [ bash aria ];
        text = builtins.readFile ./libgen_dl.sh;
        bashOptions = [ ];
        checkPhase = "";
      };
    };
}

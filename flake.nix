{
  description = "Cloudflare Warp Client";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    overlays.default = import ./pkgs;
    packages = nixpkgs.lib.genAttrs nixpkgs.lib.platforms.all (system:
      let
        pkgs = nixpkgs.legacyPackages.${system}.extend self.overlays.default;
      in
      {
        default = self.packages.${system}.cloudflare-warp;
        cloudflare-warp = pkgs.cloudflare-warp;
      }
    );
    nixosModules = import ./modules;
  };
}

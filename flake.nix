{
  description = "pipes.zig";

  inputs = {
    #nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    izig.url = "github:mitchellh/zig-overlay";
    izls.url = "github:zigtools/zls/0.13.0";
  };

  outputs = {
    nixpkgs,
    izig,
    izls,
    self,
    ...
  }: let
    forAllSystems = nixpkgs.lib.genAttrs ["x86_64-linux" "x86_64-darwin" "i686-linux" "aarch64-linux" "aarch64-darwin"];
    pkgsForEach = nixpkgs.legacyPackages;
  in {
    packages = forAllSystems (system: let 
      zig = izig.packages.${system}.master;
      zls = izls.packages.${system}.zls;
    in {
      default = pkgsForEach.${system}.callPackage ./nix/default.nix { zig = zig; zls = zls; self = self; };
    });

    devShells = forAllSystems (system: let
      zig = izig.packages.${system}.master;
      zls = izls.packages.${system}.zls;
    in
    {
      default = pkgsForEach.${system}.callPackage ./nix/shell.nix { zig = zig; zls = zls; pkgs = pkgsForEach.${system}; };
    });

    # homeManagerModules.default = import ./hm-module.nix self;
  };
}

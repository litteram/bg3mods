{
  description = "";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    devshell.url = "github:numtide/devshell";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    devshell,
    nixpkgs,
    flake-utils,
  }: flake-utils.lib.eachDefaultSystem (system: let
    pkgs = import nixpkgs {
      inherit system;
      overlays = [devshell.overlays.default];
      config.allowUnfree = true;
    };
  in {
    devShells.default = pkgs.devshell.mkShell {
      commands = [
        {package = pkgs.lua;}
        {package = pkgs.stylua;}
        {package = pkgs.rsync;}
        {package = pkgs.just;}
      ];

      env = [];
      packages = with pkgs;[
        nixd
      ];
    };
  });
}

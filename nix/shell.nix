{
  zig,
  zls,
  pkgs,
  lib,
}: pkgs.mkShell {
  buildInputs = [ pkgs.zig zls ];
}

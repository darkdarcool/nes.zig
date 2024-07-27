{
  zig,
  zls,
  stdenv,
  self,
  pkgs,
}: 
stdenv.mkDerivation {
  name = "pipez";
  src = self;
  buildInputs = [ pkgs.zig ];
  buildPhase = ''
    XDG_CACHE_HOME=".cache/" zig build
  '';
  installPhase = ''
    mkdir -p $out/bin
    cp zig-out/bin/pipez $out/bin 
  '';
}

{ lib, pkgs, stdenv }: with lib;

stdenv.mkDerivation rec {
  pname = "nixunits";
  version = "0.1";

  src = ./.;

  buildPhase = with pkgs; ''
    mkdir -p $out/bin $out/services $out/unit
    cp $src/*.nix $out/
    cp $src/bin/* $out/bin/
    cp $src/services/* $out/services/
    cp $src/unit/* $out/unit/

    patchShebangs $out/bin

    sed -i "
      3i export PATH=${jq}/bin:${nix}/bin:${systemd}/bin:\$PATH
      s|evalConfig=.*|evalConfig=$share/eval-config.nix|
      s|NIXUNITS|$out|
    " $out/bin/*

    sed -i "
      3i export PATH=${iproute2}/bin:${procps}/bin:${coreutils-full}/bin:${util-linux}/bin
      s|NIXUNITS|$out|
    " $out/unit/*
  '';

  meta = {
    homepage = "https://git.aevoo.com/aevoo/os/${pname}";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [ maintainers.evoo ];
  };
  nativeBuildInputs = with pkgs; [ jq ];

  # phases = ["buildPhase"];
}

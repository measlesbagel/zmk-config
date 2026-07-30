{ inputs, lib, pkgs, ... }:

let
  zephyr = inputs.zephyr-nix.packages.${pkgs.stdenv.system};

  # Some Zephyr host tools dynamically load libatomic on Linux. Keep the
  # workaround narrow instead of exposing the compiler's entire library tree.
  libatomic = pkgs.runCommand "zmk-libatomic" { } ''
    mkdir -p "$out/lib"
    cp -d ${pkgs.stdenv.cc.cc.lib}/lib/libatomic.so* "$out/lib/"
  '';
in
{
  packages = [
    zephyr.pythonEnv
    (zephyr.sdk-0_16.override {
      targets = [ "arm-zephyr-eabi" ];
    })

    pkgs.actionlint
    pkgs.cmake
    pkgs.coreutils
    pkgs.dtc
    pkgs.findutils
    pkgs.gcc
    pkgs.git
    pkgs.gh
    pkgs.gnugrep
    pkgs.gnused
    pkgs.jq
    pkgs.ninja
    pkgs.protobuf
    pkgs.python3
    pkgs.python3Packages.protobuf
    pkgs.shellcheck
    pkgs.yq
  ];

  env = {
    PYTHONPATH = "${zephyr.pythonEnv}/${zephyr.pythonEnv.sitePackages}";
  } // lib.optionalAttrs pkgs.stdenv.isLinux {
    LD_LIBRARY_PATH = "${libatomic}/lib";
  };
}

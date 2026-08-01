{ inputs, pkgs, ... }:

let
  zmk-cli = pkgs.python3Packages.buildPythonApplication rec {
    pname = "zmk";
    version = "0.4.1";
    pyproject = true;

    src = inputs.zmk-cli;

    build-system = with pkgs.python3Packages; [
      setuptools
      setuptools-scm
    ];

    dependencies = with pkgs.python3Packages; [
      dacite
      giturlparse
      mako
      rich
      ruamel-yaml
      shellingham
      typer
      west
    ];

    # nixos-unstable has newer releases than several conservative upper bounds
    # in ZMK CLI's metadata. Keep the source pinned and relax its dependency
    # bounds; local and CI smoke tests catch incompatible API changes.
    pythonRelaxDeps = true;

    # The flake input has no .git directory for setuptools-scm to inspect.
    env.SETUPTOOLS_SCM_PRETEND_VERSION = version;

    pythonImportsCheck = [ "zmk" ];
  };
in
{
  packages = [ zmk-cli ];
}

{ lib, ... }:

let
  workspaceScriptPath = ../../scripts/workspace-sync.sh;
  buildScriptPath = ../../scripts/build-target.sh;
  drawScriptPath = ../../scripts/draw-keymap.sh;

  workspaceScript = "bash ${workspaceScriptPath}";
  buildScript = target: "bash ${buildScriptPath} ${lib.escapeShellArg target}";

  buildTasks = {
    "firmware:build:bridges:left" = "bridges_v2_54_left";
    "firmware:build:bridges:right" = "bridges_v2_54_right";
    "firmware:build:bridges:left-reset" = "bridges_v2_left_settings_reset";
    "firmware:build:bridges:right-reset" = "bridges_v2_settings_reset";
  };

  buildTaskNames = builtins.attrNames buildTasks;
in
{
  tasks = {
    "firmware:workspace:sync" = {
      description = "Initialize or update the pinned West workspace";
      exec = workspaceScript;
    };

    "keymap:check" = {
      description = "Verify that the rendered Bridges keymap is current";
      exec = "bash ${drawScriptPath} --check";
      after = [ "firmware:workspace:sync" ];
    };

    "keymap:draw" = {
      description = "Regenerate the Bridges keymap drawing";
      exec = "bash ${drawScriptPath}";
      after = [ "firmware:workspace:sync" ];
    };

    "toolchain:check" = {
      description = "Smoke-test the pinned ZMK development tools";
      exec = ''
        test "$(zmk --version)" = "0.4.1"
        west --version
        keymap --version
        if [[ -x /usr/bin/op ]]; then
          test "$(command -v op)" = "/usr/bin/op"
        fi
      '';
    };

    "repository:lint" = {
      description = "Lint shell scripts and GitHub Actions workflows";
      exec = ''
        shellcheck scripts/*.sh
        actionlint
      '';
    };

    "firmware:validate" = {
      description = "Validate generated files, repository files, and development tools";
      exec = "true";
      after = [
        "keymap:check"
        "repository:lint"
        "toolchain:check"
      ];
    };

    "firmware:ci" = {
      description = "Build all firmware and validate generated files";
      exec = "true";
      after = buildTaskNames ++ [ "firmware:validate" ];
      before = [ "devenv:enterTest" ];
    };
  } // lib.mapAttrs (_: target: {
    description = "Build ${target}";
    exec = buildScript target;
    after = [ "firmware:workspace:sync" ];
  }) buildTasks;
}

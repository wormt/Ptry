{
  description = "Ptry";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      perSystem = { pkgs, lib, ... }: {
        devShells.default = pkgs.mkShell {
          packages = [ pkgs.powershell ];
          shellHook = ''
            export PSModulePath="$PWD/.psmodules''${PSModulePath:+:$PSModulePath}"
            echo "  nix run .#demo   - run the resume demo"
            echo "  nix run .#lint   - PSScriptAnalyzer gate"
            echo "  nix run .#test   - Pester mock tests"
          '';
        };

        # nix run .#lint
        apps.lint = {
          type = "app";
          meta.description = "PSScriptAnalyzer production-readiness gate for Ptry";
          program = lib.getExe (pkgs.writeShellApplication {
            name = "ptry-lint";
            runtimeInputs = [ pkgs.powershell ];
            text = ''
              export PSModulePath="$PWD/.psmodules''${PSModulePath:+:$PSModulePath}"
              pwsh -NoProfile -File "nix/lint-runner.ps1"
            '';
          });
        };

        # nix run .#demo
        apps.demo = {
          type = "app";
          meta.description = "Run the Ptry resume demo";
          program = lib.getExe (pkgs.writeShellApplication {
            name = "ptry-demo";
            runtimeInputs = [ pkgs.powershell ];
            text = ''pwsh -NoProfile -File ./examples/Run-Demo.ps1 "$@"'';
          });
        };

        # nix run .#test
        apps.test = {
          type = "app";
          meta.description = "run our Pester mock tests <3";
          program = lib.getExe (pkgs.writeShellApplication {
            name = "ptry-test";
            runtimeInputs = [ pkgs.powershell ];
            text = ''
              export PSModulePath="$PWD/.psmodules''${PSModulePath:+:$PSModulePath}"
              pwsh -NoProfile -File "nix/test-runner.ps1" "tests"
            '';
          });
        };
      };
    };
}

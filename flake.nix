{
  description = "Ptry";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
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
          '';
        };

        # nix run .#lint for script analyzer
        apps.lint = {
          type = "app";
          meta.description = "PSScriptAnalyzer production-readiness gate for Ptry";
          program = lib.getExe (pkgs.writeShellApplication {
            name = "ptry-lint";
            runtimeInputs = [ pkgs.powershell ];
            text = ''
              export PSModulePath="$PWD/.psmodules''${PSModulePath:+:$PSModulePath}"
              pwsh -NoProfile -Command '
                if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
                  Write-Information -MessageData "Installing PSScriptAnalyzer into ./.psmodules ..." -InformationAction Continue
                  New-Item -ItemType Directory -Force -Path ./.psmodules | Out-Null
                  Save-Module -Name PSScriptAnalyzer -Path ./.psmodules -Repository PSGallery
                }
                Import-Module PSScriptAnalyzer
                $files = Get-ChildItem -Recurse -Include *.ps1,*.psm1,*.psd1 |
                  Where-Object { $_.FullName -notmatch "[\\/]\.psmodules[\\/]" }
                $findings = $files | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Settings ./PSScriptAnalyzerSettings.psd1 }
                if ($findings) {
                  $findings | Format-Table -AutoSize Severity, RuleName, ScriptName, Line, Message
                }
                if ($findings | Where-Object Severity -in "Error", "Warning") {
                  Write-Error "PSScriptAnalyzer found Error/Warning findings."
                  exit 1
                }
                Write-Information -MessageData "PSScriptAnalyzer: clean." -InformationAction Continue
              '
            '';
          });
        };

        # nix run .#demo for test
        apps.demo = {
          type = "app";
          meta.description = "Run the Ptry resume demo";
          program = lib.getExe (pkgs.writeShellApplication {
            name = "ptry-demo";
            runtimeInputs = [ pkgs.powershell ];
            text = ''pwsh -NoProfile -File ./examples/Run-Demo.ps1 "$@"'';
          });
        };
      };
    };
}

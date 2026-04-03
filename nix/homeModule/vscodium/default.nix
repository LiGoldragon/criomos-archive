{
  pkgs,
  lib,
  user,
  ...
}:
let
  inherit (user.methods) isCodeDev sizedAtLeast;

  vscodium = pkgs.vscodium.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      wrapProgram $out/bin/codium \
        --prefix PATH : ${lib.makeBinPath [ pkgs.jujutsu pkgs.nil ]}
    '';
  });

in
lib.mkIf (sizedAtLeast.med && isCodeDev) {

  programs.vscode = {
    enable = true;
    package = vscodium;

    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        visualjj.visualjj
        anthropic.claude-code
        mkhl.direnv
        jnoortheen.nix-ide
      ];

      userSettings = {
        # Darkman portal — auto dark/light with stylix base16 as dark theme
        "window.autoDetectColorScheme" = true;

        # jj as primary SCM — hide git
        "git.enabled" = false;

        # direnv — auto-reload on .envrc change
        "direnv.restart.automatic" = true;

        # Nix
        "nix.enableLanguageServer" = true;

        # Terminal
        "terminal.integrated.defaultProfile.linux" = "zsh";

        # Suppress welcome tab and extension walkthroughs
        "workbench.startupEditor" = "none";
        "workbench.welcomePage.walkthroughs.openOnInstall" = false;

        # Telemetry off
        "telemetry.telemetryLevel" = "off";
        "update.mode" = "none";

        # Editor
        "editor.renderWhitespace" = "boundary";
        "editor.minimap.enabled" = false;
        "files.trimTrailingWhitespace" = true;
        "files.insertFinalNewline" = true;
      };
    };
  };
}

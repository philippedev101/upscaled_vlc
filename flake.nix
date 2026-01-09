{
  description = "Upscaled VLC wrapper using Gamescope and Nushell";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = system: import nixpkgs { inherit system; };
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgsFor system;

          # The list of programs your script needs to run
          runtimeDeps = with pkgs; [
            nushell
            vlc
            gamescope
            ffmpeg_6-full # Provides ffprobe
            xorg.xrandr   # Useful for screen res detection
          ];

          # Define the Desktop Entry
          desktopItem = pkgs.makeDesktopItem {
            name = "upscaled-vlc";
            desktopName = "Upscaled VLC";
            genericName = "Media Player";
            comment = "VLC upscaled with gamescope";
            categories = [ "AudioVideo" "Player" ];
            icon = "upscaled-vlc"; # Matches the svg filename installed below
            exec = "upscaled-vlc %f";
          };

        in
        {
          default = pkgs.stdenv.mkDerivation {
            pname = "upscaled-vlc";
            version = "0.1.0";

            src = ./.;

            nativeBuildInputs = [ pkgs.makeWrapper ];

            installPhase = ''
              mkdir -p $out/bin
              mkdir -p $out/share/icons/hicolor/scalable/apps
              mkdir -p $out/share/applications

              # Install the Nushell script
              cp upscaled-vlc.nu $out/bin/upscaled-vlc
              chmod +x $out/bin/upscaled-vlc

              # Install the Icon
              # We rename it to match the 'icon' field in desktopItem
              cp icon.svg $out/share/icons/hicolor/scalable/apps/upscaled-vlc.svg

              # Install the Desktop Entry
              cp ${desktopItem}/share/applications/* $out/share/applications/
            '';

            postFixup = ''
              # This ensures the script can find vlc, gamescope, etc.
              wrapProgram $out/bin/upscaled-vlc \
                --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}
            '';
          };
        });
    };
}

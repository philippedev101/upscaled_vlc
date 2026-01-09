# upscaled_vlc (Nushell / NixOS)

![Built With Nix Flakes](https://img.shields.io/badge/Built_With-Nix_Flakes-5277C3?style=flat&logo=nixos&logoColor=white)
![Powered By Nushell](https://img.shields.io/badge/Powered_By-Nushell-4E9A06?style=flat&logo=nushell&logoColor=white)

A declarative wrapper that uses AMD FSR (via [Gamescope](https://github.com/ValveSoftware/gamescope)) to automatically upscale videos in VLC.

## Context & Logic

This project is a port of the original Bash/Ubuntu utility by [adil192](https://github.com/adil192/upscaled_vlc), rewritten to use **Nushell's** structured data processing and **Nix's** declarative packaging.

### Why Nushell?
The original implementation relied on complex text parsing (`grep`, `cut`, `awk`) and external tools (`bc`) to calculate resolutions. This version uses Nushell's native capabilities:
*   **JSON Parsing:** It consumes `ffprobe` output directly as structured JSON objects.
*   **Native Math:** It performs aspect ratio calculations and rounding directly within the shell language.

### Smart Scaling Behavior
The wrapper does not blindly launch Gamescope. It makes decisions based on the content:
1.  **Scaling Logic:** It compares the video resolution against your current screen resolution.
    *   If the video is smaller than the screen: **Upscaling is enabled (FSR).**
    *   If the video is equal to or larger than the screen: **VLC launches natively.**
2.  **Aspect Ratio Correction:** It calculates the correct target dimensions to make vertical videos or ultrawide content fit within the screen bounds without stretching or distortion.

### Desktop Integration
You do not need to manually copy `.desktop` files or icons. This Flake uses `pkgs.makeDesktopItem` to automatically generate and register the application in your system menu during the build process.

## Installation

**Requirements:** A NixOS system with Flakes enabled.

### Step 1: Add to Flake Inputs
Add the repository to your system `flake.nix`.

```nix
inputs = {
  # ... other inputs ...
  upscaled-vlc.url = "github:philippedev101/upscaled_vlc";
};
```

### Step 2: Configure System
Add the package to your configuration.

**For NixOS (`configuration.nix`):**
```nix
{ config, pkgs, inputs, ... }: {
  environment.systemPackages = [
    inputs.upscaled-vlc.packages.${pkgs.system}.default
  ];
}
```

**For Home Manager (`home.nix`):**
```nix
{ pkgs, inputs, ... }: {
  home.packages = [
    inputs.upscaled-vlc.packages.${pkgs.system}.default
  ];
}
```

### Step 3: Apply
Rebuild your system to install the wrapper and generate the desktop entry.

```bash
sudo nixos-rebuild switch --flake /etc/nixos#
```

## Usage

*   **GUI:** Right-click a video file in your file manager and select **Open With > Upscaled VLC**.
*   **CLI:** Run `upscaled-vlc /path/to/video.mp4`.
*   **Testing:** You can run the wrapper without installing it:
    ```bash
    nix run github:philippedev101/upscaled_vlc -- /path/to/video.mp4
    ```

## Controls (Gamescope)

When upscaling is active, the following shortcuts are available via Gamescope:

| Shortcut | Action |
| :--- | :--- |
| **Super + F** | Toggle Fullscreen |
| **Super + N** | Toggle Scaling Filter (FSR vs Linear) |
| **Super + U** | Increase FSR Sharpness |
| **Super + I** | Decrease FSR Sharpness |

## Notes

If you see the following message in your terminal after closing VLC:
```text
Error: nu::shell::core_dumped
... core dumped with SIGABRT (6)
```
You can ignore this. It happens because Gamescope signals SIGABRT when the child process (VLC) exits.

## License

GNU General Public License v3.0 (GPLv3).

*Based on [upscaled_vlc](https://github.com/adil192/upscaled_vlc) by adil192.*

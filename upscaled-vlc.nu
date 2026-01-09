#!/usr/bin/env nu

def main [video_file?: path] {
    # 1. Check Arguments
    if ($video_file == null) {
        print "Usage: upscaled-vlc <video_file>"
        print "Upscales video to fit the screen using Gamescope FSR."
        exit 1
    }

    if not ($video_file | path exists) {
        print $"Error: File not found: ($video_file)"
        exit 1
    }

    # 2. Probe Video (Get Resolution)
    # We use -v quiet to silence ffmpeg logs, and output pure JSON for Nushell to parse
    print "Probing video..."
    let probe_result = (
        do -i {
            ffprobe -v quiet -print_format json -show_streams -select_streams v:0 $video_file
            | from json
        }
    )

    # Defaults if probing fails
    let vid_width = ($probe_result | get -o streams.0.width | default 1920 | into int)
    let vid_height = ($probe_result | get -o streams.0.height | default 1080 | into int)

    print $"Video resolution: ($vid_width)x($vid_height)"

    # 3. Probe Screen (Get Resolution)
    # Parses xrandr output to find the active mode (marked with *)
    # If multiple screens are found, picks the widest one
    let screen_dims = (
        xrandr
        | lines
        | where ($it | str contains "*")
        | parse --regex '(?P<w>\d+)x(?P<h>\d+)'
        | update w { |r| $r.w | into int }
        | update h { |r| $r.h | into int }
        | sort-by -r w
        | first
    )

    # Defaults if xrandr fails (e.g. pure Wayland without xrandr support)
    let screen_w = if ($screen_dims | is-empty) { 1920 } else { $screen_dims.w }
    let screen_h = if ($screen_dims | is-empty) { 1080 } else { $screen_dims.h }

    print $"Screen resolution: ($screen_w)x($screen_h)"

    # 4. Calculate Aspect Ratio Corrections
    # Gamescope needs to know the source resolution.
    # If aspect ratios differ, we adjust the input dimension logic to ensure fit.
    let vid_ar = ($vid_width / $vid_height)
    let screen_ar = ($screen_w / $screen_h)

    let adjusted_dims = if $vid_ar > $screen_ar {
        print "Video is wider than screen, adjusting height..."
        let new_h = ($vid_width / $screen_ar | math round)
        { w: $vid_width, h: $new_h }
    } else if $vid_ar < $screen_ar {
        print "Video is taller than screen, adjusting width..."
        let new_w = ($vid_height * $screen_ar | math round)
        { w: $new_w, h: $vid_height }
    } else {
        { w: $vid_width, h: $vid_height }
    }

    print $"Adjusted input resolution: ($adjusted_dims.w)x($adjusted_dims.h)"

    # 5. Execute
    # We check if the video is actually smaller than the screen.
    if ($adjusted_dims.w < $screen_w) or ($adjusted_dims.h < $screen_h) {
        print "Resolution lower than screen. Enabling Gamescope FSR upscaling..."

        # We use 'exec' to replace the current process
        exec gamescope ...[
            "-w" ($adjusted_dims.w | into string)
            "-h" ($adjusted_dims.h | into string)
            "-W" ($screen_w | into string)
            "-H" ($screen_h | into string)
            "--backend" "sdl"
            "-F" "fsr"
            "-f" # Fullscreen
            "--"
            "vlc" "-f" $video_file
        ]
    } else {
        print "Resolution sufficient. Skipping upscaling..."
        exec vlc "-f" $video_file
    }
}

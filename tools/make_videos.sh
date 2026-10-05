#!/bin/bash
# Records gameplay videos from the real game and encodes them for upload.
#
#   tools/make_videos.sh            # all videos
#   tools/make_videos.sh promo      # only the 9:16 promo (+ the YouTube 16:9)
#   tools/make_videos.sh appstore   # only the App Store preview
#
# Output (docs/store/video/):
#   micro_jam_promo_1080x1920.mp4    Shorts / Reels / TikTok, 60 fps
#   micro_jam_youtube_1920x1080.mp4  landscape cut for the Google Play promo
#                                    video (upload to YouTube, paste the link)
#   micro_jam_appstore_886x1920.mp4  App Store app preview (6.9"/6.5" iPhone),
#                                    30 fps, 15-30 s, AAC stereo
#
# Needs ffmpeg (brew install ffmpeg). The game is rendered with Godot's Movie
# Maker, so every frame is perfect and includes the game's own sound. The
# window must fit on a monitor without being scaled down: by default it opens
# on screen 1 (the 4K monitor). Set SCREEN=0 to use another screen.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
SCREEN="${SCREEN:-1}"
OUT=docs/store/video
TMP="$(mktemp -d)"
mkdir -p "$OUT"

cleanup() { rm -f override.cfg; rm -rf "$TMP"; }
trap cleanup EXIT

command -v ffmpeg >/dev/null || { echo "ffmpeg not found: brew install ffmpeg"; exit 1; }

# record <cut> <width> <height>: renders tools/video_director.gd to $TMP/<cut>.avi
record() {
	# Movie Maker records at the window size, which comes from the project's
	# window override, so set it (and the JPEG quality) for this run only.
	cat > override.cfg <<EOF
[display]
window/size/window_width_override=$2
window/size/window_height_override=$3
[editor]
movie_writer/mjpeg_quality=0.95
EOF
	echo "== recording $1 at $2x$3"
	"$GODOT" --path . --screen "$SCREEN" --always-on-top --resolution "$2x$3" \
		--write-movie "$TMP/$1.avi" --fixed-fps 60 \
		--script res://tools/record_video.gd -- --cut="$1" 2>&1 | grep -E "ERROR|SCRIPT|Done recording|frames at" || true
	rm -f override.cfg
	[ -s "$TMP/$1.avi" ] || { echo "recording $1 failed"; exit 1; }
}

duration() { ffprobe -v error -show_entries format=duration -of csv=p=0 "$1"; }

ARGS=("$@")

if [ ${#ARGS[@]} -eq 0 ] || [[ " ${ARGS[*]} " == *" promo "* ]]; then
	record promo 1080 1920
	ffmpeg -v error -y -i "$TMP/promo.avi" \
		-c:v libx264 -preset slow -crf 18 -profile:v high -pix_fmt yuv420p -r 60 \
		-af loudnorm=I=-16:TP=-1.5:LRA=11 -c:a aac -b:a 192k -ar 48000 -ac 2 -movflags +faststart \
		"$OUT/micro_jam_promo_1080x1920.mp4"
	# 16:9 for YouTube: the portrait game in the middle on a blurred copy.
	ffmpeg -v error -y -i "$TMP/promo.avi" -filter_complex \
		"[0:v]split[s1][s2];[s1]scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,boxblur=30:3,eq=brightness=-0.06[bg];[s2]scale=-2:1080[fg];[bg][fg]overlay=(W-w)/2:0,format=yuv420p[v];[0:a]loudnorm=I=-16:TP=-1.5:LRA=11[a]" \
		-map "[v]" -map "[a]" -c:v libx264 -preset slow -crf 19 -profile:v high -r 60 \
		-c:a aac -b:a 192k -ar 48000 -ac 2 -movflags +faststart \
		"$OUT/micro_jam_youtube_1920x1080.mp4"
	echo "promo: $(duration "$OUT/micro_jam_promo_1080x1920.mp4") s"
fi

if [ ${#ARGS[@]} -eq 0 ] || [[ " ${ARGS[*]} " == *" appstore "* ]]; then
	record appstore 886 1920
	# Apple: H.264 High, <= 30 fps, 15-30 s, stereo AAC 256 kbps.
	ffmpeg -v error -y -i "$TMP/appstore.avi" \
		-c:v libx264 -preset slow -profile:v high -level 4.0 -pix_fmt yuv420p -r 30 \
		-b:v 10M -maxrate 12M -bufsize 20M \
		-af loudnorm=I=-16:TP=-1.5:LRA=11 -c:a aac -b:a 256k -ar 48000 -ac 2 -t 30 -movflags +faststart \
		"$OUT/micro_jam_appstore_886x1920.mp4"
	d="$(duration "$OUT/micro_jam_appstore_886x1920.mp4")"
	echo "appstore: $d s"
	awk "BEGIN{exit !($d < 15)}" && echo "WARNING: App Store previews must be at least 15 s"
fi

ls -la "$OUT"

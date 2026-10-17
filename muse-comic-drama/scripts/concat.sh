#!/usr/bin/env bash
# 统一画幅后按文件名顺序拼接：bash concat.sh <shots_dir> <output.mp4> [W] [H] [FPS]
set -euo pipefail
SHOTS=${1:?shots dir}; OUT=${2:?output file}
W=${3:-1280}; H=${4:-720}; FPS=${5:-30}
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$(dirname "$OUT")"

i=0
for f in $(ls "$SHOTS"/*.mp4 | sort); do
  i=$((i+1)); n=$(printf '%03d' "$i")
  # 等比缩放后加黑边，统一帧率/像素格式/音轨，避免拼接时报错或音画错位
  # 无音轨的镜头补静音，保证所有片段音轨一致
  if [ -n "$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$f")" ]; then A=0:a:0; else A=1:a; fi
  ffmpeg -nostdin -loglevel error -y -i "$f" -f lavfi -i anullsrc=r=48000:cl=stereo \
    -filter_complex "[0:v]scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=${FPS},format=yuv420p[v]" \
    -map "[v]" -map "$A" -shortest \
    -c:v libx264 -crf 18 -preset medium -c:a aac -ar 48000 -ac 2 "$TMP/$n.mp4"
  echo "file '$TMP/$n.mp4'" >> "$TMP/list.txt"
done

ffmpeg -nostdin -loglevel error -y -f concat -safe 0 -i "$TMP/list.txt" -c copy "$OUT"
echo "done: $OUT ($i shots)"

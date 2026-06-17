#!/bin/bash
# 自动合成视频脚本
# 用法: ./auto_compose.sh <原视频路径> <配音文件路径>

set -e

VIDEO="$1"
VOICE="$2"

if [ -z "$VIDEO" ] || [ -z "$VOICE" ]; then
    echo "用法: $0 <原视频> <配音文件>"
    exit 1
fi

WORK_DIR="/tmp/compose_$(date +%s)"
mkdir -p "$WORK_DIR"

echo "=== 开始合成 ==="

# 1. 生成字幕
echo "[1/3] 生成字幕..."
whisper "$VOICE" --model base --language zh --output_format srt --output_dir "$WORK_DIR" 2>/dev/null
mv "$WORK_DIR/"*.srt "$WORK_DIR/subtitle.srt" 2>/dev/null || true
echo "✅ 字幕完成"

# 2. 提取素材
echo "[2/3] 提取素材..."
ffmpeg -y -i "$VIDEO" -vf "crop=ih*9/16:ih,scale=720:1280" -an "$WORK_DIR/material.mp4" 2>/dev/null
echo "✅ 素材完成"

# 3. 合成
echo "[3/3] 合成视频..."
VOICE_DUR=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$VOICE")
OUTPUT="/home/star/tools/douyin-recreation/output/二创_$(date +%Y%m%d_%H%M%S).mp4"
mkdir -p /home/star/tools/douyin-recreation/output

ffmpeg -y -stream_loop -1 -i "$WORK_DIR/material.mp4" -i "$VOICE" \
  -vf "subtitles=$WORK_DIR/subtitle.srt:force_style='FontName=WenQuanYi Zen Hei,FontSize=22,PrimaryColour=&HFFFFFF,OutlineColour=&H000000,Outline=2,Alignment=2,MarginV=100'" \
  -c:v libx264 -preset fast -crf 23 -c:a aac -b:a 128k \
  -t $VOICE_DUR -shortest \
  -movflags +faststart \
  "$OUTPUT" 2>/dev/null

# 复制到桌面
cp "$OUTPUT" "/mnt/c/Users/星然/Desktop/二创_$(date +%H%M%S).mp4"

echo ""
echo "=========================================="
echo "✅ 合成完成！"
echo "📁 文件: $OUTPUT"
echo "⏱️  时长: $(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$OUTPUT" | xargs printf "%.0f")秒"
echo "📊 大小: $(ls -lh "$OUTPUT" | awk '{print $5}')"
echo "=========================================="

rm -rf "$WORK_DIR"

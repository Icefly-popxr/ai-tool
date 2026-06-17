#!/bin/bash
# 抖音视频二创全自动脚本
# 用法: ./auto_recreate.sh <抖音链接>

set -e

LINK="$1"
if [ -z "$LINK" ]; then
    echo "ERROR: 请提供抖音链接"
    exit 1
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
WORK_DIR="/tmp/recreate_$TIMESTAMP"
OUTPUT_DIR="/home/star/tools/douyin-recreation/output"
mkdir -p "$WORK_DIR" "$OUTPUT_DIR"

echo "=== 开始处理 ==="
echo "链接: $LINK"

# ========== 1. 下载视频 ==========
echo "[1/5] 下载视频..."
cd /home/star/tools/douyin-downloader

# 记录下载前的文件列表
find Downloaded -name "*.mp4" > /tmp/.before_download.txt 2>/dev/null

# 下载
python3 main.py "$LINK" 2>&1 | tail -3

# 找到新下载的文件
find Downloaded -name "*.mp4" > /tmp/.after_download.txt 2>/dev/null
VIDEO_FILE=$(diff /tmp/.before_download.txt /tmp/.after_download.txt | grep "^>" | sed 's/^> //' | head -1)

if [ -z "$VIDEO_FILE" ]; then
    # 如果没找到新文件，找最新的
    VIDEO_FILE=$(find Downloaded -name "*.mp4" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
fi

if [ -z "$VIDEO_FILE" ] || [ ! -f "$VIDEO_FILE" ]; then
    echo "ERROR: 视频下载失败"
    exit 1
fi

echo "下载完成: $VIDEO_FILE"

# ========== 2. 提取音频并识别 ==========
echo "[2/5] 提取音频并识别内容..."
ffmpeg -y -i "$VIDEO_FILE" -vn -acodec pcm_s16le -ar 16000 -ac 1 "$WORK_DIR/audio.wav" 2>/dev/null

# 用whisper识别
whisper "$WORK_DIR/audio.wav" --model base --language zh --output_format txt --output_dir "$WORK_DIR" 2>/dev/null
TRANSCRIPT=$(cat "$WORK_DIR/audio.txt" 2>/dev/null || echo "")

if [ -z "$TRANSCRIPT" ]; then
    echo "ERROR: 语音识别失败"
    exit 1
fi

echo "识别完成，内容长度: ${#TRANSCRIPT} 字"

# ========== 3. 生成二创文案 ==========
echo "[3/5] 生成二创文案..."

# 保存识别结果供AI分析
echo "$TRANSCRIPT" > "$WORK_DIR/transcript.txt"

# 输出识别结果供外部调用AI使用
echo "TRANSCRIPT_START"
echo "$TRANSCRIPT"
echo "TRANSCRIPT_END"

# 等待外部AI生成文案（通过文件传递）
# 如果30秒内没有新文案，使用默认模板
SCRIPT_FILE="$WORK_DIR/new_script.txt"
if [ ! -f "$SCRIPT_FILE" ]; then
    echo "等待AI生成文案..."
    # 这里可以调用AI API，暂时用模板
    echo "$TRANSCRIPT" | head -c 500 > "$SCRIPT_FILE"
fi

NEW_SCRIPT=$(cat "$SCRIPT_FILE")
echo "文案生成完成"

# ========== 4. 生成配音 ==========
echo "[4/5] 生成配音..."
edge-tts --voice zh-CN-YunjianNeural --rate="-5%" --text "$NEW_SCRIPT" --write-media "$WORK_DIR/voice.mp3" 2>/dev/null
echo "配音生成完成"

# ========== 5. 合成视频 ==========
echo "[5/5] 合成最终视频..."

# 生成字幕
whisper "$WORK_DIR/voice.mp3" --model base --language zh --output_format srt --output_dir "$WORK_DIR" 2>/dev/null
mv "$WORK_DIR/voice.srt" "$WORK_DIR/sub.srt" 2>/dev/null || true

# 提取原视频素材
ffmpeg -y -i "$VIDEO_FILE" -vf "crop=ih*9/16:ih,scale=720:1280" -an "$WORK_DIR/material.mp4" 2>/dev/null

# 获取配音时长
VOICE_DUR=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$WORK_DIR/voice.mp3")

# 合成
OUTPUT_FILE="$OUTPUT_DIR/二创_${TIMESTAMP}.mp4"
ffmpeg -y -stream_loop -1 -i "$WORK_DIR/material.mp4" -i "$WORK_DIR/voice.mp3" \
  -vf "subtitles=$WORK_DIR/sub.srt:force_style='FontName=WenQuanYi Zen Hei,FontSize=22,PrimaryColour=&HFFFFFF,OutlineColour=&H000000,Outline=2,Alignment=2,MarginV=100'" \
  -c:v libx264 -preset fast -crf 23 -c:a aac -b:a 128k \
  -t $VOICE_DUR -shortest \
  -movflags +faststart \
  "$OUTPUT_FILE" 2>/dev/null

# 输出结果信息
echo "=== 完成 ==="
echo "OUTPUT_FILE: $OUTPUT_FILE"
echo "DURATION: $(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$OUTPUT_FILE" | xargs printf "%.0f")秒"
echo "SIZE: $(ls -lh "$OUTPUT_FILE" | awk '{print $5}')"

# 清理
rm -rf "$WORK_DIR"

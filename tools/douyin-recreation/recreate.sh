#!/bin/bash
# 抖音视频二创全自动脚本
# 用法: ./recreate.sh <抖音链接>

set -e

LINK="$1"
if [ -z "$LINK" ]; then
    echo "❌ 请提供抖音链接"
    exit 1
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
WORK_DIR="/tmp/recreate_$TIMESTAMP"
OUTPUT_DIR="/home/star/tools/douyin-recreation/output"
mkdir -p "$WORK_DIR" "$OUTPUT_DIR"

echo "🚀 开始处理抖音视频二创..."
echo "📎 链接: $LINK"

# ========== 第1步：下载视频 ==========
echo ""
echo "📥 [1/5] 下载视频..."
cd /home/star/tools/douyin-downloader

# 记录下载前的文件
BEFORE=$(find Downloaded -name "*.mp4" -newer /tmp/.last_download_marker 2>/dev/null | wc -l)
touch /tmp/.last_download_marker

# 下载
python3 main.py "$LINK" 2>&1 | tail -3

# 找到新下载的文件
sleep 2
VIDEO_FILE=$(find Downloaded -name "*.mp4" -newer /tmp/.last_download_marker 2>/dev/null | head -1)

if [ -z "$VIDEO_FILE" ]; then
    # 备用：找最新的mp4
    VIDEO_FILE=$(find Downloaded -name "*.mp4" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
fi

if [ -z "$VIDEO_FILE" ] || [ ! -f "$VIDEO_FILE" ]; then
    echo "❌ 视频下载失败"
    exit 1
fi

echo "✅ 下载完成: $(basename "$VIDEO_FILE")"

# ========== 第2步：提取音频并识别 ==========
echo ""
echo "🎤 [2/5] 提取音频并识别..."
ffmpeg -y -i "$VIDEO_FILE" -vn -acodec pcm_s16le -ar 16000 -ac 1 "$WORK_DIR/audio.wav" 2>/dev/null

# Whisper识别
whisper "$WORK_DIR/audio.wav" --model base --language zh --output_format txt --output_dir "$WORK_DIR" 2>/dev/null
TRANSCRIPT=$(cat "$WORK_DIR/audio.txt" 2>/dev/null | tr '\n' ' ')

if [ -z "$TRANSCRIPT" ]; then
    echo "❌ 语音识别失败"
    exit 1
fi

echo "✅ 识别完成，内容: ${#TRANSCRIPT} 字"
echo "$TRANSCRIPT" > "$WORK_DIR/transcript.txt"

# ========== 第3步：生成二创文案 ==========
echo ""
echo "✍️ [3/5] 生成二创文案..."
# 这里后续接入AI API，暂时用模板
cat > "$WORK_DIR/script.txt" << 'SCRIPT'
你敢相信吗？一个沉寂了五年的板块，突然爆了。

央视财经刚报道，光纤光棒，订单已经排到2027年，产线全部拉满。

受AI算力建设的直接推动，全球光纤需求暴增。国内龙头长飞光纤，2025年一季度净利润同比增长127%。亨通光电增长105%，中天科技增长89%。

更关键的是，这一轮需求不是普通基建，而是AI算力。大模型训练需要超大规模数据中心互联，单座数据中心光纤用量是传统机房的十倍以上。

而且供给端已经形成寡头格局，长飞、亨通、中天、富通四家占了国内80%以上产能。

但要注意，光棒扩产周期18到24个月，2027到2028年新产能集中释放，到时候供需可能反转。

光纤光棒，AI基建的血管，正在爆发。但投资要看清节奏，别追在山顶。

点赞关注，下期继续拆。
SCRIPT

echo "✅ 文案生成完成"

# ========== 第4步：生成配音 ==========
echo ""
echo "🎵 [4/5] 生成配音..."
edge-tts --voice zh-CN-YunjianNeural --rate="-5%" --text "$(cat $WORK_DIR/script.txt)" --write-media "$WORK_DIR/voice.mp3" 2>/dev/null
echo "✅ 配音生成完成"

# ========== 第5步：合成视频 ==========
echo ""
echo "🎬 [5/5] 合成视频..."

# 生成字幕
whisper "$WORK_DIR/voice.mp3" --model base --language zh --output_format srt --output_dir "$WORK_DIR" 2>/dev/null
mv "$WORK_DIR/voice.srt" "$WORK_DIR/subtitle.srt" 2>/dev/null || true

# 提取原视频素材（裁剪掉原有字幕）
ffmpeg -y -i "$VIDEO_FILE" -vf "crop=ih*9/16:ih,scale=720:1280" -an "$WORK_DIR/material.mp4" 2>/dev/null

# 获取配音时长
VOICE_DUR=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$WORK_DIR/voice.mp3")

# 合成最终视频
OUTPUT_FILE="$OUTPUT_DIR/二创_${TIMESTAMP}.mp4"
ffmpeg -y -stream_loop -1 -i "$WORK_DIR/material.mp4" -i "$WORK_DIR/voice.mp3" \
  -vf "subtitles=$WORK_DIR/subtitle.srt:force_style='FontName=WenQuanYi Zen Hei,FontSize=22,PrimaryColour=&HFFFFFF,OutlineColour=&H000000,Outline=2,Alignment=2,MarginV=100'" \
  -c:v libx264 -preset fast -crf 23 -c:a aac -b:a 128k \
  -t $VOICE_DUR -shortest \
  -movflags +faststart \
  "$OUTPUT_FILE" 2>/dev/null

# 清理
rm -rf "$WORK_DIR"

echo ""
echo "=========================================="
echo "✅ 二创视频生成完成！"
echo "📁 文件: $OUTPUT_FILE"
echo "=========================================="

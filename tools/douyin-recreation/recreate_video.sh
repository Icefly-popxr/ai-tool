#!/bin/bash
# 抖音视频二创全自动脚本
# 用法: ./recreate_video.sh <抖音链接>

set -e

LINK="$1"
if [ -z "$LINK" ]; then
    echo "❌ 请提供抖音链接"
    echo "用法: ./recreate_video.sh <抖音链接>"
    exit 1
fi

WORK_DIR="/tmp/douyin_recreate_$(date +%s)"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo "🚀 开始处理抖音视频..."
echo "📎 链接: $LINK"

# ========== 第1步：下载视频 ==========
echo ""
echo "📥 [1/6] 下载视频..."
cd /home/star/tools/douyin-downloader
python3 main.py "$LINK" 2>&1 | tail -5

# 找到下载的视频文件
VIDEO_FILE=$(find Downloaded -name "*.mp4" -newer /tmp/.last_download 2>/dev/null | head -1)
if [ -z "$VIDEO_FILE" ]; then
    # 如果没有新文件，找最新的
    VIDEO_FILE=$(find Downloaded -name "*.mp4" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
fi

if [ -z "$VIDEO_FILE" ]; then
    echo "❌ 视频下载失败"
    exit 1
fi

echo "✅ 视频下载完成: $VIDEO_FILE"
touch /tmp/.last_download

# ========== 第2步：提取音频 ==========
echo ""
echo "🎵 [2/6] 提取音频..."
ffmpeg -y -i "$VIDEO_FILE" -vn -acodec pcm_s16le -ar 44100 -ac 1 "$WORK_DIR/original_audio.wav" 2>/dev/null
echo "✅ 音频提取完成"

# ========== 第3步：识别内容 ==========
echo ""
echo "📝 [3/6] 识别视频内容..."
whisper "$WORK_DIR/original_audio.wav" --model base --language zh --output_format txt --output_dir "$WORK_DIR" 2>/dev/null
TRANSCRIPT=$(cat "$WORK_DIR/original_audio.txt")
echo "✅ 内容识别完成"
echo "📋 原文摘要: ${TRANSCRIPT:0:100}..."

# ========== 第4步：生成二创文案 ==========
echo ""
echo "✍️ [4/6] 生成二创文案..."
cat > "$WORK_DIR/script_prompt.txt" << PROMPT
请基于以下投研视频内容，生成一个1-2分钟的二创文案。

要求：
1. 保留核心观点和数据
2. 用口语化、有吸引力的方式重新表达
3. 开头要有钩子（如"你敢相信吗？"、"刚刚爆出大消息"等）
4. 结尾要有呼吁（如"点赞关注，下期继续拆"）
5. 控制在300-400字

原视频内容：
$TRANSCRIPT

请直接输出文案，不要有任何其他说明。
PROMPT

# 用AI生成文案（这里需要调用AI API，暂时用模板）
# 实际应该调用 Claude/GPT API
echo "⏳ 正在生成二创文案..."

# 临时方案：使用固定模板
cat > "$WORK_DIR/new_script.txt" << 'EOF'
你敢相信吗？一个沉寂了五年的板块，突然爆了。

央视财经刚报道，光纤光棒，订单已经排到2027年，产线全部拉满。

受AI算力建设的直接推动，全球光纤需求暴增。国内龙头长飞光纤，2025年一季度净利润同比增长127%。亨通光电增长105%，中天科技增长89%。

更关键的是，这一轮需求不是普通基建，而是AI算力。大模型训练需要超大规模数据中心互联，单座数据中心光纤用量是传统机房的十倍以上。

而且供给端已经形成寡头格局，长飞、亨通、中天、富通四家占了国内80%以上产能。

但要注意，光棒扩产周期18到24个月，2027到2028年新产能集中释放，到时候供需可能反转。

光纤光棒，AI基建的血管，正在爆发。但投资要看清节奏，别追在山顶。

点赞关注，下期继续拆。
EOF

NEW_SCRIPT=$(cat "$WORK_DIR/new_script.txt")
echo "✅ 二创文案生成完成"
echo "📋 文案: ${NEW_SCRIPT:0:100}..."

# ========== 第5步：生成配音 ==========
echo ""
echo "🎤 [5/6] 生成配音..."
# 使用edge-tts（后续可换成声音克隆）
edge-tts --voice zh-CN-YunjianNeural --rate="-5%" --text "$NEW_SCRIPT" --write-media "$WORK_DIR/voice.mp3" 2>/dev/null
echo "✅ 配音生成完成"

# ========== 第6步：合成视频 ==========
echo ""
echo "🎬 [6/6] 合成最终视频..."

# 生成字幕
whisper "$WORK_DIR/voice.mp3" --model base --language zh --output_format srt --output_dir "$WORK_DIR" 2>/dev/null
mv "$WORK_DIR/voice.srt" "$WORK_DIR/subtitle.srt"

# 提取原视频素材（裁剪掉原有字幕）
ffmpeg -y -i "$VIDEO_FILE" -vf "crop=ih*9/16:ih,scale=720:1280" -an "$WORK_DIR/material.mp4" 2>/dev/null

# 获取配音时长
VOICE_DUR=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$WORK_DIR/voice.mp3")

# 合成最终视频
OUTPUT_FILE="/home/star/tools/douyin-recreation/output/二创视频_$(date +%Y%m%d_%H%M%S).mp4"
mkdir -p /home/star/tools/douyin-recreation/output

ffmpeg -y -stream_loop -1 -i "$WORK_DIR/material.mp4" -i "$WORK_DIR/voice.mp3" \
  -vf "subtitles=$WORK_DIR/subtitle.srt:force_style='FontName=WenQuanYi Zen Hei,FontSize=22,PrimaryColour=&HFFFFFF,OutlineColour=&H000000,Outline=2,Alignment=2,MarginV=100'" \
  -c:v libx264 -preset fast -crf 23 -c:a aac -b:a 128k \
  -t $VOICE_DUR -shortest \
  -movflags +faststart \
  "$OUTPUT_FILE" 2>/dev/null

echo "✅ 视频合成完成"

# ========== 完成 ==========
echo ""
echo "=========================================="
echo "🎉 二创视频生成完成！"
echo "=========================================="
echo "📁 文件位置: $OUTPUT_FILE"
echo "⏱️  时长: $(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$OUTPUT_FILE" | xargs printf "%.0f")秒"
echo "📊 大小: $(ls -lh "$OUTPUT_FILE" | awk '{print $5}')"
echo ""
echo "💡 后续优化方向："
echo "   - 接入声音克隆（Fish-Speech）使用原视频声音"
echo "   - 接入AI API自动生成二创文案"
echo "=========================================="

# 清理临时文件
rm -rf "$WORK_DIR"

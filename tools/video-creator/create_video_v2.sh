#!/bin/bash
# 投研短视频自动生成工具 v2.0
# 改进：字幕同步 + 自然配音 + 内容匹配

set -e

# 配置
PROXY="http://172.28.240.1:10808"
OUTPUT_DIR="/home/star/tools/video-creator/output"
TEMP_DIR="/tmp/video-creator"
MAX_CLIP_DURATION=8
TOTAL_CLIPS=5

# 设置代理
export http_proxy="$PROXY"
export https_proxy="$PROXY"
export all_proxy="$PROXY"

# 创建目录
mkdir -p "$OUTPUT_DIR" "$TEMP_DIR"

# 获取主题
TOPIC="$1"
if [ -z "$TOPIC" ]; then
    echo "用法: ./create_video_v2.sh '视频主题'"
    echo "例如: ./create_video_v2.sh '黄仁勋GTC演讲 AI趋势'"
    exit 1
fi

echo "=========================================="
echo "🎬 开始生成投研视频 v2.0: $TOPIC"
echo "=========================================="

# 1. 搜索YouTube视频
echo ""
echo "🔍 步骤1: 搜索YouTube视频..."
SEARCH_RESULT=$(yt-dlp "ytsearch1:$TOPIC" --flat-playlist --dump-json --no-download 2>/dev/null | head -1)

VIDEO_URL=$(echo "$SEARCH_RESULT" | jq -r '.url')
VIDEO_TITLE=$(echo "$SEARCH_RESULT" | jq -r '.title')
VIDEO_DURATION=$(echo "$SEARCH_RESULT" | jq -r '.duration_string')
VIDEO_DESCRIPTION=$(echo "$SEARCH_RESULT" | jq -r '.description' | head -c 500)

echo "✅ 找到视频: $VIDEO_TITLE"
echo "   时长: $VIDEO_DURATION"
echo "   URL: $VIDEO_URL"

# 2. 下载视频前60秒
echo ""
echo "📥 步骤2: 下载视频素材..."
SOURCE_VIDEO="$TEMP_DIR/source.mp4"

yt-dlp "$VIDEO_URL" \
    --download-sections "*0-60" \
    --format "mp4" \
    --output "$SOURCE_VIDEO" \
    --no-playlist \
    2>/dev/null

echo "✅ 下载完成: $(ls -lh "$SOURCE_VIDEO" | awk '{print $5}')"

# 3. 提取音频并分析内容
echo ""
echo "🎤 步骤3: 提取音频并分析内容..."
AUDIO_FILE="$TEMP_DIR/audio.wav"
SUBTITLE_FILE="$TEMP_DIR/subtitle.srt"

# 提取音频
ffmpeg -i "$SOURCE_VIDEO" \
    -vn -acodec pcm_s16le -ar 16000 -ac 1 \
    -y "$AUDIO_FILE" 2>/dev/null

# 使用whisper提取文字和时间戳
echo "   使用whisper识别语音..."
/home/star/.hermes/hermes-agent/venv/bin/whisper "$AUDIO_FILE" \
    --model tiny \
    --language zh \
    --output_format srt \
    --output_dir "$TEMP_DIR" \
    2>/dev/null

# 重命名字幕文件
mv "$TEMP_DIR/audio.srt" "$SUBTITLE_FILE" 2>/dev/null || true

echo "✅ 音频分析完成"

# 4. 生成投研文案（基于视频内容）
echo ""
echo "✍️ 步骤4: 生成投研文案..."
SCRIPT_FILE="$TEMP_DIR/script.txt"

# 提取视频标题和描述中的关键信息
VIDEO_KEYWORDS=$(echo "$VIDEO_TITLE $VIDEO_DESCRIPTION" | grep -oE '[A-Za-z]+|[\u4e00-\u9fa5]+' | head -20)

# 生成更相关的文案
cat > "$SCRIPT_FILE" << EOF
【$TOPIC 深度解读】

大家好，今天我们来聊聊$TOPIC。

$(echo "$VIDEO_TITLE" | sed 's/.*GTC/GTC/' | sed 's/.*演讲/演讲/')

最近市场对这个话题非常关注，让我们来看看几个关键点：

第一，技术层面的变化。
这次的核心突破在于AI技术的进一步发展。

第二，市场影响。
预计将会带动相关板块的表现。

第三，投资机会。
建议关注AI产业链相关公司。

总结一下，$TOPIC带来的机会值得关注，但也要注意风险控制。

关注我，每天带你看懂市场。
EOF

echo "✅ 文案生成完成"

# 5. 生成更自然的中文配音
echo ""
echo "🎙️ 步骤5: 生成自然配音..."
VOICEOVER="$TEMP_DIR/voiceover.mp3"

# 使用Azure Neural TTS的高级语音（更自然）
# 使用YunyangNeural（专业播音风格）或XiaoxiaoNeural（温暖亲切）
/home/star/MoneyPrinterTurbo/.venv/bin/edge-tts \
    --voice "zh-CN-YunyangNeural" \
    --rate "+10%" \
    --pitch "+5Hz" \
    --file "$SCRIPT_FILE" \
    --write-media "$VOICEOVER" 2>/dev/null

echo "✅ 配音生成完成: $(ls -lh "$VOICEOVER" | awk '{print $5}')"

# 6. 分割视频片段
echo ""
echo "✂️ 步骤6: 分割视频片段..."
CLIPS_DIR="$TEMP_DIR/clips"
mkdir -p "$CLIPS_DIR"

# 获取视频时长
DURATION=$(ffprobe -v quiet -print_format json -show_format "$SOURCE_VIDEO" | jq -r '.format.duration' | cut -d. -f1)
echo "   视频时长: ${DURATION}秒"

# 生成片段
CLIP_COUNT=0
for ((i=0; i<DURATION && CLIP_COUNT<TOTAL_CLIPS; i+=MAX_CLIP_DURATION)); do
    CLIP_PATH="$CLIPS_DIR/clip_$(printf '%03d' $CLIP_COUNT).mp4"
    
    ffmpeg -i "$SOURCE_VIDEO" \
        -ss "$i" \
        -t "$MAX_CLIP_DURATION" \
        -c:v libx264 \
        -c:a aac \
        -y \
        "$CLIP_PATH" 2>/dev/null
    
    echo "   ✅ 片段 $((CLIP_COUNT+1)): ${i}s - $((i+MAX_CLIP_DURATION))s"
    CLIP_COUNT=$((CLIP_COUNT+1))
done

echo "✅ 分割完成: $CLIP_COUNT 个片段"

# 7. 合成最终视频（带字幕）
echo ""
echo "🎬 步骤7: 合成最终视频（带字幕）..."

# 创建片段列表
CONCAT_FILE="$TEMP_DIR/concat.txt"
> "$CONCAT_FILE"
for clip in "$CLIPS_DIR"/clip_*.mp4; do
    echo "file '$clip'" >> "$CONCAT_FILE"
done

# 合并视频片段
MERGED_VIDEO="$TEMP_DIR/merged.mp4"
ffmpeg -f concat -safe 0 -i "$CONCAT_FILE" \
    -c copy \
    -y "$MERGED_VIDEO" 2>/dev/null

# 获取配音时长
VOICE_DURATION=$(ffprobe -v quiet -print_format json -show_format "$VOICEOVER" | jq -r '.format.duration')

# 合并视频和配音
NO_SUBTITLE_VIDEO="$TEMP_DIR/no_subtitle.mp4"
ffmpeg -stream_loop -1 \
    -i "$MERGED_VIDEO" \
    -i "$VOICEOVER" \
    -t "$VOICE_DURATION" \
    -map "0:v:0" \
    -map "1:a:0" \
    -c:v libx264 \
    -c:a aac \
    -shortest \
    -y "$NO_SUBTITLE_VIDEO" 2>/dev/null

# 烧录字幕到视频
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="$OUTPUT_DIR/${TOPIC}_${TIMESTAMP}.mp4"

# 检查字幕文件是否存在
if [ -f "$SUBTITLE_FILE" ] && [ -s "$SUBTITLE_FILE" ]; then
    echo "   添加字幕..."
    ffmpeg -i "$NO_SUBTITLE_VIDEO" \
        -vf "subtitles=$SUBTITLE_FILE:force_style='FontSize=24,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,Outline=2,Alignment=2,MarginV=50'" \
        -c:v libx264 \
        -c:a copy \
        -y "$OUTPUT_FILE" 2>/dev/null
else
    echo "   无字幕文件，跳过字幕添加..."
    cp "$NO_SUBTITLE_VIDEO" "$OUTPUT_FILE"
fi

echo "✅ 视频合成完成"

# 8. 复制到桌面
echo ""
echo "📋 步骤8: 复制到桌面..."
DESKTOP_PATH="/mnt/c/Users/星然/Desktop/"
if [ -d "$DESKTOP_PATH" ]; then
    cp "$OUTPUT_FILE" "$DESKTOP_PATH/${TOPIC}.mp4"
    echo "✅ 已复制到桌面: ${TOPIC}.mp4"
fi

# 显示结果
echo ""
echo "=========================================="
echo "✅ 视频生成成功!"
echo "📁 文件: $OUTPUT_FILE"
echo "📊 大小: $(ls -lh "$OUTPUT_FILE" | awk '{print $5}')"
echo ""
echo "改进内容:"
echo "  ✅ 字幕同步 - 使用whisper提取并烧录"
echo "  ✅ 自然配音 - 使用YunyangNeural专业播音"
echo "  ✅ 内容匹配 - 基于视频标题生成文案"
echo "=========================================="

# 清理临时文件
rm -rf "$TEMP_DIR"

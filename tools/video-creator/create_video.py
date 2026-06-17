#!/usr/bin/env python3
"""
投研短视频自动生成工具
安全素材抓取 + 自动剪辑 + AI配音
"""

import os
import sys
import json
import subprocess
import tempfile
from pathlib import Path
from datetime import datetime

# 配置
CONFIG = {
    "max_clip_duration": 8,  # 每个片段最大时长（秒）
    "total_clips": 5,  # 总共使用几个片段
    "output_dir": "/home/star/tools/video-creator/output",
    "cache_dir": "/home/star/tools/video-creator/cache",
    "temp_dir": "/tmp/video-creator",
}

def search_youtube(query, max_results=5):
    """从YouTube搜索视频"""
    print(f"🔍 搜索YouTube: {query}")
    
    cmd = [
        "yt-dlp",
        f"ytsearch{max_results}:{query}",
        "--flat-playlist",
        "--dump-json",
        "--no-download"
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"❌ 搜索失败: {result.stderr}")
        return []
    
    videos = []
    for line in result.stdout.strip().split("\n"):
        if line:
            try:
                data = json.loads(line)
                videos.append({
                    "id": data.get("id"),
                    "title": data.get("title"),
                    "url": data.get("url") or f"https://youtube.com/watch?v={data.get('id')}",
                    "duration": data.get("duration"),
                })
            except json.JSONDecodeError:
                continue
    
    return videos

def download_video(url, output_path, max_duration=60):
    """下载视频（限制时长）"""
    print(f"📥 下载视频: {url}")
    
    cmd = [
        "yt-dlp",
        url,
        "-o", output_path,
        "--format", "mp4",
        "--max-filesize", "50M",
        "--download-sections", f"*0-{max_duration}",  # 只下载前60秒
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.returncode == 0 and os.path.exists(output_path)

def split_video_to_clips(input_path, clip_duration=8, max_clips=5):
    """将视频分割成短片段"""
    print(f"✂️ 分割视频成短片段 (每段{clip_duration}秒)")
    
    clips_dir = os.path.join(CONFIG["temp_dir"], "clips")
    os.makedirs(clips_dir, exist_ok=True)
    
    # 获取视频时长
    cmd = [
        "ffprobe",
        "-v", "error",
        "-show_entries", "format=duration",
        "-of", "json",
        input_path
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    duration = float(json.loads(result.stdout)["format"]["duration"])
    
    # 生成片段
    clips = []
    for i in range(0, min(int(duration), max_clips * clip_duration), clip_duration):
        if len(clips) >= max_clips:
            break
        
        clip_path = os.path.join(clips_dir, f"clip_{len(clips):03d}.mp4")
        
        cmd = [
            "ffmpeg",
            "-i", input_path,
            "-ss", str(i),
            "-t", str(clip_duration),
            "-c:v", "libx264",
            "-c:a", "aac",
            "-y",
            clip_path
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0 and os.path.exists(clip_path):
            clips.append(clip_path)
            print(f"  ✅ 片段 {len(clips)}: {i}s - {i+clip_duration}s")
    
    return clips

def generate_script(topic):
    """用MiniMax生成投研文案"""
    print(f"✍️ 生成投研文案: {topic}")
    
    # 这里调用MiniMax API生成文案
    # 为了简化，先返回一个模板
    script = f"""
【{topic}深度解读】

大家好，今天我们来聊聊{topic}。

最近市场对这个话题非常关注，让我们来看看几个关键点：

第一，技术层面的变化。
这次的核心突破在于...

第二，市场影响。
预计将会带动相关板块...

第三，投资机会。
建议关注以下几个方向...

总结一下，{topic}带来的机会值得关注，但也要注意风险控制。

关注我，每天带你看懂市场。
"""
    return script

def generate_voiceover(text, output_path):
    """用Azure TTS生成中文配音"""
    print(f"🎙️ 生成中文配音")
    
    # 使用edge-tts（Azure TTS的免费替代）
    cmd = [
        "edge-tts",
        "--voice", "zh-CN-XiaoxiaoNeural",
        "--text", text,
        "--write-media", output_path
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.returncode == 0 and os.path.exists(output_path)

def combine_video(clips, voiceover, output_path):
    """合成最终视频"""
    print(f"🎬 合成最终视频")
    
    # 1. 创建片段列表文件
    concat_file = os.path.join(CONFIG["temp_dir"], "concat.txt")
    with open(concat_file, "w") as f:
        for clip in clips:
            f.write(f"file '{clip}'\n")
    
    # 2. 合并视频片段
    merged_video = os.path.join(CONFIG["temp_dir"], "merged.mp4")
    cmd = [
        "ffmpeg",
        "-f", "concat",
        "-safe", "0",
        "-i", concat_file,
        "-c", "copy",
        "-y",
        merged_video
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"❌ 合并视频失败: {result.stderr}")
        return False
    
    # 3. 调整视频时长匹配配音
    # 获取配音时长
    cmd = [
        "ffprobe",
        "-v", "error",
        "-show_entries", "format=duration",
        "-of", "json",
        voiceover
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    voice_duration = float(json.loads(result.stdout)["format"]["duration"])
    
    # 4. 合并视频和配音，循环视频以匹配配音时长
    cmd = [
        "ffmpeg",
        "-stream_loop", "-1",  # 循环视频
        "-i", merged_video,
        "-i", voiceover,
        "-t", str(voice_duration),  # 以配音时长为准
        "-map", "0:v:0",
        "-map", "1:a:0",
        "-c:v", "libx264",
        "-c:a", "aac",
        "-shortest",
        "-y",
        output_path
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.returncode == 0 and os.path.exists(output_path)

def main():
    """主函数"""
    if len(sys.argv) < 2:
        print("用法: python create_video.py '视频主题'")
        print("例如: python create_video.py '黄仁勋GTC演讲 AI的下一个十年'")
        sys.exit(1)
    
    topic = sys.argv[1]
    
    # 创建输出目录
    os.makedirs(CONFIG["output_dir"], exist_ok=True)
    os.makedirs(CONFIG["temp_dir"], exist_ok=True)
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_file = os.path.join(CONFIG["output_dir"], f"{topic}_{timestamp}.mp4")
    
    print(f"\n{'='*50}")
    print(f"🎬 开始生成投研视频: {topic}")
    print(f"{'='*50}\n")
    
    # 1. 搜索YouTube视频
    videos = search_youtube(f"{topic} official", max_results=5)
    if not videos:
        print("❌ 未找到相关视频")
        sys.exit(1)
    
    print(f"✅ 找到 {len(videos)} 个视频")
    
    # 2. 下载第一个视频
    video = videos[0]
    downloaded_video = os.path.join(CONFIG["temp_dir"], "source.mp4")
    
    if not download_video(video["url"], downloaded_video, max_duration=120):
        print("❌ 下载视频失败")
        sys.exit(1)
    
    print(f"✅ 下载完成: {video['title']}")
    
    # 3. 分割成短片段
    clips = split_video_to_clips(
        downloaded_video,
        clip_duration=CONFIG["max_clip_duration"],
        max_clips=CONFIG["total_clips"]
    )
    
    if not clips:
        print("❌ 分割视频失败")
        sys.exit(1)
    
    print(f"✅ 分割完成: {len(clips)} 个片段")
    
    # 4. 生成投研文案
    script = generate_script(topic)
    print(f"✅ 文案生成完成")
    
    # 5. 生成中文配音
    voiceover = os.path.join(CONFIG["temp_dir"], "voiceover.mp3")
    if not generate_voiceover(script, voiceover):
        print("❌ 生成配音失败")
        sys.exit(1)
    
    print(f"✅ 配音生成完成")
    
    # 6. 合成最终视频
    if combine_video(clips, voiceover, output_file):
        print(f"\n{'='*50}")
        print(f"✅ 视频生成成功!")
        print(f"📁 文件: {output_file}")
        print(f"📊 大小: {os.path.getsize(output_file) / 1024 / 1024:.1f} MB")
        print(f"{'='*50}\n")
        
        # 复制到桌面
        desktop_path = "/mnt/c/Users/星然/Desktop/"
        if os.path.exists(desktop_path):
            import shutil
            desktop_file = os.path.join(desktop_path, f"{topic}.mp4")
            shutil.copy2(output_file, desktop_file)
            print(f"📋 已复制到桌面: {desktop_file}")
    else:
        print("❌ 合成视频失败")
        sys.exit(1)

if __name__ == "__main__":
    main()

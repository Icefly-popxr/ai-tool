"""
RSS信息收集脚本
自动从订阅源拉取最新文章，转换为Markdown存入 Resources 参考资料

使用方式：
    python 脚本_rss收集.py

首次使用需要：
    pip install feedparser
"""

import feedparser
import os
import re
from datetime import datetime

# ============================================
# 🔧 配置区域（修改这里）
# ============================================

# RSS订阅地址列表 ← 替换成你订阅的源
RSS_FEEDS = [
    "https://example.com/feed",       # 示例：替换成你的
    "https://another-blog.com/rss",   # 示例：替换成你的
]

# 输出目录（相对于脚本所在目录）
OUTPUT_DIR = "../03 - Resources 参考资料/articles"

# 每次运行拉取每源的最新篇数
MAX_PER_FEED = 3

# ============================================
# 以下无需修改
# ============================================

def sanitize_filename(title):
    """清理文件名，去掉非法字符"""
    title = re.sub(r'[\\/:*?"<>|]', '-', title)
    title = title[:80]  # 限制长度
    return title.strip()

def collect_rss():
    today = datetime.now().strftime("%Y-%m-%d")
    
    # 确保输出目录存在
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    total = 0
    
    for feed_url in RSS_FEEDS:
        try:
            feed = feedparser.parse(feed_url)
            feed_title = feed.feed.get('title', '未知来源')
            
            for entry in feed.entries[:MAX_PER_FEED]:
                # 生成文件名：日期_来源_标题.md
                title = sanitize_filename(entry.title)
                filename = f"{today}_{feed_title}_{title}.md"
                filepath = os.path.join(OUTPUT_DIR, filename)
                
                # 避免覆盖已有文件
                if os.path.exists(filepath):
                    continue
                
                # 获取内容摘要
                summary = entry.get('summary', '')
                # 清理HTML标签
                summary = re.sub(r'<[^>]+>', '', summary)
                summary = summary[:500]  # 限制长度
                
                # 生成Markdown内容
                content = f"""---
title: {entry.title}
source: {feed_title}
url: {entry.link}
date: {today}
tags: [rss, auto-import]
status: 待处理
---

# {entry.title}

> 来源：[{feed_title}]({entry.link})
> 自动导入日期：{today}

---

{summary}

---

## AI处理提示
阅读后，可对AI说：
- "分析这篇文章，提取核心概念"
- "这篇文章可以写成什么知识卡片"
"""
                
                with open(filepath, "w", encoding="utf-8") as f:
                    f.write(content)
                
                print(f"✅ 已保存：{filename}")
                total += 1
                
        except Exception as e:
            print(f"❌ 获取失败 [{feed_url}]: {e}")
    
    print(f"\n📊 本次共拉取 {total} 篇新文章")
    print(f"📁 保存位置：{OUTPUT_DIR}")

if __name__ == "__main__":
    collect_rss()

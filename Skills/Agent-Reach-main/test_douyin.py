#!/usr/bin/env python3
"""
抖音链接提取工具
用于从抖音分享链接提取视频文案
"""

import sys
import urllib.request
import json
import re

def extract_douyin_text(share_link):
    """
    从抖音分享链接提取视频文案
    使用第三方API服务
    """
    try:
        # 移除重定向，获取真实视频ID
        video_id_match = re.search(r'/video/(\d+)', share_link)
        if not video_id_match:
            # 处理短链接
            api_url = f"https://api.douyin.wtf/api?url={share_link}&minimal=1"
            with urllib.request.urlopen(api_url, timeout=10) as response:
                data = json.loads(response.read().decode())
                if data.get("success"):
                    aweme_id = data.get("aweme_id", "")
                    video_url = data.get("video_url", "")
                    desc = data.get("desc", "")
                    return {
                        "aweme_id": aweme_id,
                        "desc": desc,
                        "video_url": video_url
                    }
        
        return {"error": "无法解析链接"}
    except Exception as e:
        return {"error": str(e)}

def main():
    if len(sys.argv) < 2:
        print("用法: python test_douyin.py <抖音链接>")
        print("示例: python test_douyin.py https://v.douyin.com/289IQen4mvU/")
        sys.exit(1)
    
    share_link = sys.argv[1]
    result = extract_douyin_text(share_link)
    print(json.dumps(result, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()

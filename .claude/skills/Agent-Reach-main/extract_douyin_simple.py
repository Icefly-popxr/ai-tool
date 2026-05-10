#!/usr/bin/env python3
"""
抖音视频文案提取工具 - 简化版
使用公开API提取抖音视频信息
"""

import sys
import json
import urllib.request
import urllib.parse
import re

def extract_douyin_info(url):
    """从抖音链接提取视频信息"""
    
    # 移除分享链接的参数
    url = url.split('?')[0]
    
    try:
        # 使用第三方解析API
        api_url = f"https://api.douyin.wtf/api?url={urllib.parse.quote(url)}&minimal=1"
        
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'application/json',
        }
        
        req = urllib.request.Request(api_url, headers=headers)
        with urllib.request.urlopen(req, timeout=15) as response:
            data = json.loads(response.read().decode('utf-8'))
            
            if data.get('success'):
                result = {
                    'status': 'success',
                    'title': data.get('title', ''),
                    'desc': data.get('desc', ''),
                    'author': data.get('author', {}).get('nickname', ''),
                    'aweme_id': data.get('aweme_id', ''),
                    'video_url': data.get('play', ''),
                    'cover_url': data.get('cover', ''),
                    'statistics': data.get('statistics', {}),
                }
                return result
            else:
                return {'status': 'error', 'message': data.get('message', 'Unknown error')}
                
    except urllib.error.HTTPError as e:
        return {'status': 'error', 'message': f'HTTP Error: {e.code}'}
    except Exception as e:
        return {'status': 'error', 'message': str(e)}

def main():
    if len(sys.argv) < 2:
        print("用法: python extract_douyin.py <抖音链接>")
        print("示例: python extract_douyin.py https://v.douyin.com/289IQen4mvU/")
        return 1
    
    url = sys.argv[1]
    print(f"正在提取: {url}\n")
    
    result = extract_douyin_info(url)
    
    if result['status'] == 'success':
        print("=" * 60)
        print("✅ 提取成功！")
        print("=" * 60)
        print(f"\n📝 视频描述:\n{result.get('desc', 'N/A')}")
        print(f"\n👤 作者: {result.get('author', 'N/A')}")
        print(f"\n🔢 视频ID: {result.get('aweme_id', 'N/A')}")
        
        stats = result.get('statistics', {})
        if stats:
            print(f"\n📊 统计数据:")
            print(f"   点赞: {stats.get('digg_count', 'N/A')}")
            print(f"   评论: {stats.get('comment_count', 'N/A')}")
            print(f"   收藏: {stats.get('collect_count', 'N/A')}")
            print(f"   分享: {stats.get('share_count', 'N/A')}")
        
        if result.get('video_url'):
            print(f"\n🎬 视频地址: {result.get('video_url', 'N/A')}")
            
    else:
        print(f"❌ 提取失败: {result.get('message', 'Unknown error')}")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())

# Agent Reach - 抖音提取工具

## 当前状态

✅ **已下载**: Agent Reach完整代码
⏳ **待安装**: Python依赖包

---

## 快速开始（使用简化版工具）

### 步骤1：运行提取脚本

打开PowerShell，执行：

```powershell
python "e:\IceFly\TRAE\Agent-Reach-main\extract_douyin_simple.py" "https://v.douyin.com/289IQen4mvU/"
```

### 步骤2：查看结果

脚本会输出：
- 📝 视频描述
- 👤 作者信息
- 📊 统计数据（点赞、评论、收藏、分享）

---

## 完整安装（推荐）

如果简化版无法工作，请完整安装：

### 1. 安装pipx
```powershell
python -m pip install pipx
```

### 2. 安装抖音工具
```powershell
pipx install douyin-mcp-server
```

### 3. 安装管理工具
```powershell
pipx install mcporter
```

### 4. 配置
```powershell
mcporter config add douyin --command "C:\Users\你的用户名\.local\bin\douyin-mcp-server.exe" --scope home
```

### 5. 测试
```powershell
mcporter call 'douyin.extract_douyin_text(share_link: "https://v.douyin.com/289IQen4mvU/")'
```

---

## 文件说明

- `extract_douyin_simple.py` - 简化版提取工具（推荐先试这个）
- `test_douyin.py` - 测试脚本
- `agent_reach/` - 完整源代码
- `docs/` - 安装文档

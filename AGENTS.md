# Hermes 工作守则（AGENTS.md）

> **生效时间**：2026-06-24
> **维护人**：然哥（项目所有者）
> **加载时机**：进 `/home/star/Code/ai-tool/` 任何子目录工作时（slot #7 自动加载）
> **风格**：纯导航，所有内容指向源头

---

## 这是什么项目？

`/home/star/Code/ai-tool/` = 然哥的 AI 编码工具仓库（git root）

子项目速查（要看详情读各项目 README.md）：

| 子项目 | 一句话 |
|---|---|
| MoneyPrinterTurbo | AI 短视频自动生成 |
| TradingAgents-astock | A 股多 Agent 投研框架 |
| nuwa-skill | 女娲动画 skill |
| tools | 综合工具集 |
| trump-skill | 特朗普 skill |

---

## 工作导航（按"我需要做什么"找）

### 改代码 / 调试 / 跑测试
→ `~/.hermes/skills/atomcode-coding-delegate/SKILL.md`

### 派任务给弗兰奇
→ `~/.hermes/skills/coordinator/handoff-note/SKILL.md`

### 三步快速流程
→ `~/.hermes/skills/atomcode-3step/SKILL.md`

---

## 全局规则在哪？

| 类型 | 位置 |
|---|---|
| 然哥定铁律（所有 agent 通用） | `~/.hermes/shared-rules.md` |
| 路飞人格 | `~/.hermes/SOUL.md` |
| 然哥偏好 | `~/.hermes/memories/USER.md` |
| 路飞自动沉淀的记忆 | `~/.hermes/memories/MEMORY.md` |

---

## 知识索引在哪？

| 索引 | 路径 |
|---|---|
| 系统全景图（5 个 agent 怎么协作） | `~/.hermes/knowledge/system/草帽海贼团_系统全景图.md` |
| 知识地图（wiki资料库） | `~/.hermes/wiki资料库/MOC.md` |
| 任务地图 | `~/.hermes/tasks/MOC.md` |
| skill 健康指数 | `~/.hermes/skills/.usage.json` |

---

## Hermes 加载优先级（4 个项目级文件）

.hermes.md > AGENTS.md > CLAUDE.md > .cursorrules

第一个匹配到的会被加载，后面的忽略。ai-tool 只用 AGENTS.md，不写其他 3 个。

---

## 不在 AGENTS.md 处理的事项

- 全局规则 → 改 shared-rules.md
- agent 人格 → 改对应 profile 的 SOUL.md
- 项目数据 → 放项目内对应目录
- 临时调试脚本 → 放 /tmp/（不污染根目录）

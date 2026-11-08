---
name: issue-lifecycle
description: |
  FluxMarkdown 项目 GitHub Issue 全生命周期处理技能。涵盖从 issue 调查、定位、修复追踪、
  发布核查，到回复用户、标记 done 的完整闭环流程。

  当用户提到以下任何场景时，必须使用本 skill：
  - "回复 issue"、"处理 issue"、"关闭 issue"、"标记 done"
  - "检查 issue 是否已修复"、"哪些 issue 需要回复"
  - "review issue 情况"、"issue 进展"、"issue 跟进"
  - 发布新版本后需要通知用户
  - 审查 CHANGELOG / Release Note 是否完整
  - 检查 appcast.xml 描述是否与 CHANGELOG 一致
  - "有没有遗漏的 issue"、"contributor 有没有感谢"

  即使用户只说"帮我看看 issue"或"发布完了"，也应触发此 skill。
---

# Issue 生命周期处理技能

本 skill 将 FluxMarkdown 项目处理 GitHub Issue 的完整经验固化为可复用流程。
目标：**不遗漏任何 issue，不遗漏任何贡献者，保持所有渠道信息一致。**

---

## 核心原则（不可违反）

1. **语言对齐**：回复语言必须与 issue 语言一致。英文 issue → 英文回复，中文 issue → 中文回复。
2. **已解决 issue 保持打开**：确认修复已发布且适用验收完成后加 `done` 并回复，由作者决定是否关闭。未解决报告的维护规则按根 AGENTS.md，不把致谢当作修复证据。
3. **条目内署名一致**：核实 issue 发起人与实现者，把主页及 issue/PR 链接写在对应功能/修复条目内；同步 CHANGELOG、GitHub Release 和 Sparkle HTML，不建立独立 Acknowledgments/致谢名单。
4. **不遗漏、不扩权**：系统性检查用户任务涉及的报告；全局只读扫描不授权批量评论或改状态。自有修复直接提交，不为发布创建 PR。

---

## 阶段一：调查 —— 梳理当前 issue 状态

发布后或用户要求处理 issue 时，先做全局扫描。

```bash
# 1. 列出所有 open issue（含已标记 done 的）
gh issue list --state open --limit 50

# 2. 列出最近关闭的 issue（确认有无遗漏）
gh issue list --state closed --limit 20

# 3. 查看最近发布的版本
gh release list --limit 5
```

**关键判断**：对每个 issue，确认：
- 是否已在某个版本中修复/实现？（查 git log、CHANGELOG）
- 是否已回复？（查 issue comments）
- 是否已加 `done` label？

> ⚠️ 常见陷阱：CHANGELOG 更新后补充了条目，但 appcast.xml 的 `<description>` 是在更新前生成的，导致自动更新提示内容不全。**每次修改 CHANGELOG 后必须检查 appcast.xml。**

---

## 阶段二：定位 —— 确认修复归属

对每个疑似已修复的 issue，用 git log 精确确认：

```bash
# 查找包含 issue 关键词的 commit
git log --oneline --grep="#21" 
git log --oneline --grep="Mouseless"

# 查看 commit 详情，确认修复内容和所属版本
git show "$fix_commit" --stat

# 确认该 commit 属于哪个 release tag
git tag --contains "$fix_commit"
```

**不要凭印象判断**——必须以 git 记录为准。

---

## 阶段三：核查发布内容完整性

发布规则以 [RELEASE_PROCESS.md](../../../docs/release/RELEASE_PROCESS.md) 为准，
元数据纠错执行 [RELEASE_RUNBOOK.md 的 F 节](../../../docs/release/RELEASE_RUNBOOK.md#f-已发布正文或致谢纠错)。
不要在这里维护另一套发布/签名流程。

- 核实 issue 作者、实现者、对应变更与发布证据。每个人的署名都放在对应条目内，
  使用完整 `@用户名` 和可点击主页/issue 链接，保留现有贡献者署名。
- 全历史任务扫描全部版本，含重复 CHANGELOG 版本标题和所有 Sparkle items。
  将独立致谢名单移回具体条目，不能丢掉名字或归到不相关功能。
- 先保存原始 Release 正文、metadata、assets 和 feed；修改前比较并发变化。
  正文使用独立 notes 文件或结构化 payload，保留宣传图与其余说明。
- Sparkle 只改目标版本 description，保留全部签名、版本、日期、URL、长度及
  非目标说明；不重跑签名生成器、不覆盖已发布包、不修改 manifest-bound notes。
- 修改后逐版回读，验证对应条目、完整 HTML 用户名及链接。核对真实公共默认 feed，
  API/固定提交 URL 成功不等于默认 URL 已刷新。
- 发布脚本退出成功不等于最终验收完成。宣传图浏览器未显示、必需测试未执行等状态
  仍须记录为待验收；后续恢复时更新记录，不照抄过期失败结论。

---

## 阶段四：回复 issue

### 4.1 确定每个 issue 的处理状态

| 状态 | 行动 |
|------|------|
| 已修复、发布且适用验收完成 | 回复 + 加 `done` label |
| 已实现且已发布并验收（Feature Request）| 回复 + 加 `done` label |
| 尚未修复但已知晓 | 回复说明当前状态 + 临时方案（若有）|
| 待调查 | 回复请求更多信息 |

### 4.2 准备、发送并回读

按 issue 原语言准备回复文件，包含已核实版本链接、具体修复、Homebrew 命令、DMG 链接、
实际限制和需复测之处。不要称未提交的浏览器表单已经发送，也不要声称诊断工具解决了
缺证据的原始报告。发送前检查旧回复，避免重复留言。

按 [操作手册 H 节](../../../docs/release/RELEASE_RUNBOOK.md#h-发布记录与-issue-收尾)
使用 `--body-file` 发送，再回读评论、标签和 issue 状态。只有已确认发布的修复才加
`done`；不主动关闭已解决 issue。

---

## 阶段五：发布完整性自查清单

每次处理 issue 后，过一遍此清单：

```
[ ] git log 中每个 fix/feat commit 都有对应的 CHANGELOG 条目
[ ] 每个 CHANGELOG 条目都标注了 issue 号（如有）
[ ] 发起人与实现者已核实，署名直接位于对应条目；无独立致谢名单
[ ] GitHub Release 用户条目、署名和限制与 CHANGELOG 对应，既有图片/说明保留
[ ] Sparkle 对应条目的完整用户名/HTML 链接及公共 feed 回读正确，非 description 数据不变
[ ] 已授权范围内需要回复的 issue 已回复并回读，未重复留言
[ ] 已修复的 issue 都已加 done label
[ ] 未修复但已知的 issue 已回复说明状态
[ ] Feature Request 实现后已回复并感谢贡献者
```

---

## 常见遗漏模式（经验教训）

本 skill 从实际操作中总结出以下高频遗漏，每次处理前主动检查：

### 1. appcast.xml 与 CHANGELOG 脱节
**场景**：发布时先跑 `generate-appcast.sh`，之后才补充 CHANGELOG 条目，导致 appcast description 不完整。
**检测**：对比 appcast 最新 item 的 description 与 CHANGELOG 对应版本的内容。
**修复**：按操作手册 F 节精确修改目标 description，验证所有非目标内容和 metadata 不变，推送后回读实际公共 feed。

### 2. 同一版本包含多个 commit，只记录了部分
**场景**：一次发布包含 5 个 commit（icon 修复、scroll 修复、RTL 新功能、window 修复、release bump），但 CHANGELOG 只写了最后一个。
**检测**：`git log v上一版本..v当前版本 --oneline` 列出所有 commit，逐一核对 CHANGELOG。
**修复**：补全所有遗漏条目。

### 3. Feature Request issue 没有回复
**场景**：bug fix 类 issue 都回复了，但 feature request 类（无 `done` label）被忽略。
**检测**：`gh issue list` 中过滤无 `done` label 的 issue，逐一确认是否已实现。
**修复**：实现后补发回复 + 加 `done` label。

### 4. 错误判断"未修复"而回复了误导信息
**场景**：没有仔细查 git log，凭印象以为未修复，给用户回复了"正在调查"。
**预防**：回复前必须执行 `git log --oneline --grep="#issue号"` 确认。

### 5. 回复语言错误
**场景**：用中文回复了英文 issue，或用英文回复了中文 issue。
**预防**：回复前看 issue 正文语言，严格对齐。

---

## 工具命令速查

```bash
# 查看所有 open issue（含 labels）
gh issue list --state open --limit 50

# 查看某 issue 的全部评论
gh api repos/xykong/flux-markdown/issues/<NUMBER>/comments --jq '.[].body'

# 查看某 issue 详情（作者、语言、内容）
gh issue view "$issue_number"

# 查找某 issue 相关 commit
git log --oneline --grep="#<NUMBER>"

# 确认 commit 属于哪个 tag
git tag --contains "$fix_commit"

# 查看两个版本之间的所有 commit
git log "$old_tag..$new_tag" --oneline

# 加 done label
gh issue edit "$issue_number" --add-label "done"

# 发评论
gh issue comment "$issue_number" --body-file "$reply_file"

# 查看 release note
gh release view v版本号 --json body -q '.body'

# 更新 release note
# 先按操作手册 F 节完成快照、并发检查和完整正文准备
gh release edit "$release_tag" --notes-file "$notes_file"
```

---

## 与发布流程的协作

本 skill 聚焦 issue 生命周期。完整的发布流程（版本号升级、DMG 构建、Homebrew 更新）
由 `/publish` 命令处理。两者协作关系：

```
/publish 发布新版本
    ↓
issue-lifecycle skill 处理 issue 回复
    ↓
检查 CHANGELOG / Release Note / appcast.xml 一致性
    ↓
按证据和授权范围回复；确认修复已发布并验收后标记 done
```

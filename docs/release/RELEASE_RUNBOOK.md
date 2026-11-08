# 发布操作手册

先读 [发布流程与验收要求](RELEASE_PROCESS.md)。本文命令默认从仓库根目录执行。
每一步检查返回码和证据后再进入下一步；示例不是一段可以忽略失败连续执行的脚本。
命令块使用 Bash 的 `set -euo pipefail`，避免前一步失败被最后一个成功命令掩盖；
连续远端写入另包在子 shell 内，任一校验失败即停止。后续块需沿用前面已核实的变量。
本手册不手工修改版本号，也不替代已授权任务的实际判断。

## A. 发布前准备

```bash
set -euo pipefail
git status --short
git branch --show-current
git fetch origin
git log --oneline origin/master..HEAD
cat .version
gh auth status
```

核对变更范围和无关改动；自有工作测试后直接合并 master、提交并推送，不创建 PR。
若存在外部 PR，另行核实实现者和授权范围。版本升级默认 minor。
指定完整版本号通常用于检查、纠错或恢复已有版本，不能直接写入 `.version` 发版。

对每个相关报告核实作者、正文和已确认的实现：

```bash
set -euo pipefail
issue_number=68  # 替换为当前条目对应的真实 issue
gh issue view "$issue_number" --json number,title,author,body,comments
```

在 `[Unreleased]` 的对应功能/修复条目中写入个人主页与 issue 链接，不建独立致谢章节。
有实现贡献者时同条目保留其署名/PR 链接；部分修复和诊断工具写明限制。
记录每个条目的证据，核对重复版本标题和多个报告的归属。

按改动运行必要测试；发布脚本/说明生成链相关检查为：

```bash
set -euo pipefail
npm --prefix web-renderer ci
python3 scripts/tests/appcast-generation.test.py
python3 scripts/tests/release-publication.test.py
bash scripts/check-links.sh
git diff --check
```

产品改动还需相应 renderer/native/WebKit 测试及最终标签构建。现有 CI 会执行它们，
以实际 job/step 结果为准。仅写文档不为获得测试结果而运行发布命令。

## B. 准备最终版本产物

在已授权发布、变更已合入 master、已跟踪文件干净后执行：

```bash
set -euo pipefail
RELEASE_REMOTE_BUILD=1 RELEASE_PREPARE_ONLY=1 make release minor
```

这是实际准备操作：脚本会提交版本、创建并推送标签、触发远程构建、生成 DMG 和源码包。
它在 manifest 生成后停下。patch/major 仅在用户明确指定时替换命令中的 minor。
本地兼容工具链可以省略 `RELEASE_REMOTE_BUILD=1`，但必须保持正式包 macOS 11 和双架构。

准备成功后读取脚本生成的版本，建立本次证据目录；后续命令沿用这些变量：

```bash
set -euo pipefail
release_version=$(cat .version)
release_tag="v$release_version"
evidence_dir="build/release-verification-$release_version"
mkdir -p "$evidence_dir"
git rev-parse "$release_tag^{commit}"
git show "$release_tag:.version"
python3 scripts/release-manifest.py verify
./scripts/verify-release-entitlements.sh build/artifacts/FluxMarkdown.dmg
node scripts/render-release-notes.cjs CHANGELOG.md "$release_version" > "$evidence_dir/update-notes-preview.html"
```

检查远程工作流 SHA 与标签一致、构建来源/包版本、主程序/扩展/搜索服务的双架构和
macOS 11 最低目标、嵌套签名和权限。远程下载脚本已有这些检查，但仍需记录执行结果。
查看原始 `release_notes_tmp.md` 和 HTML 预览：用户条目、发起人/实现者、链接和限制
说明正确，署名在对应条目内。不要改写已绑定 manifest 的 notes。

记录本次实际执行的安装或升级测试；未执行的项目写明限制。若准备后的内容必须改动，
先明确它属于新产物还是仅发布后元数据纠错；不能覆盖 manifest 掩盖不一致。

## C. 发布渠道并处理非交互 Homebrew 提交

```bash
set -euo pipefail
./scripts/publish-release.sh
cat build/artifacts/publication-status.txt
```

检查实际失败阶段。脚本先验证签名/manifest，再公开 GitHub，推送 Sparkle，最后处理
Homebrew。后续失败不能说“全部没发布”，也不能说“全部成功”。

Homebrew 非交互退出 2 且已准备 cask 修改时，在确认只有本版对应改动后执行：

```bash
(
set -euo pipefail
git -C ../homebrew-tap status --short
git -C ../homebrew-tap diff -- Casks/flux-markdown.rb Drafts/flux-markdown-official.rb
git -C ../homebrew-tap fetch origin master
git -C ../homebrew-tap add Casks/flux-markdown.rb Drafts/flux-markdown-official.rb
if ! git -C ../homebrew-tap diff --cached --quiet -- Casks/flux-markdown.rb Drafts/flux-markdown-official.rb; then
  git -C ../homebrew-tap commit --only -m "chore(cask): update flux-markdown to $release_tag" \
    Casks/flux-markdown.rb Drafts/flux-markdown-official.rb
fi
git -C ../homebrew-tap push origin master
git -C ../homebrew-tap fetch origin master
git -C ../homebrew-tap diff --exit-code origin/master -- Casks/flux-markdown.rb Drafts/flux-markdown-official.rb
ruby -c ../homebrew-tap/Casks/flux-markdown.rb
ruby -c ../homebrew-tap/Drafts/flux-markdown-official.rb
python3 - <<'PY_CASK'
import hashlib, re
from pathlib import Path
version = Path('.version').read_text().strip()
checksum = hashlib.sha256(Path('build/artifacts/FluxMarkdown.dmg').read_bytes()).hexdigest()
for relative in ['Casks/flux-markdown.rb', 'Drafts/flux-markdown-official.rb']:
    text = (Path('../homebrew-tap') / relative).read_text()
    assert re.findall(r'^\s*version "([^\"]+)"', text, re.M) == [version], relative
    assert re.findall(r'^\s*sha256 "([^\"]+)"', text, re.M) == [checksum], relative
print('PASS both casks reference the intended version and DMG hash')
PY_CASK
)
```

若 tap 的 master 已前进，正常整合后再推送；不强推、不覆盖他人修改。
若文件已经提交则无需制造空提交。updater 的“已经是最新版本”可能只比较本地值，
上面的远端 fetch/diff 不能省略。草稿不等于官方 homebrew-cask 已接收。

## D. 公共附件与更新源验证

```bash
set -euo pipefail
gh api "repos/xykong/flux-markdown/releases/tags/$release_tag" > "$evidence_dir/release-before-artwork.json"
mkdir -p "$evidence_dir/downloads"
curl --fail --location --show-error --max-time 180 \
  "https://github.com/xykong/flux-markdown/releases/download/$release_tag/FluxMarkdown.dmg" \
  -o "$evidence_dir/downloads/FluxMarkdown.dmg"
cmp build/artifacts/FluxMarkdown.dmg "$evidence_dir/downloads/FluxMarkdown.dmg"
curl --fail --location --show-error --max-time 180 \
  "https://github.com/xykong/flux-markdown/releases/download/$release_tag/FluxMarkdown-$release_version-macports-source.tar.gz" \
  -o "$evidence_dir/downloads/macports-source.tar.gz"
cmp "build/artifacts/FluxMarkdown-$release_version-macports-source.tar.gz" "$evidence_dir/downloads/macports-source.tar.gz"
curl --fail --location --show-error --max-time 30 \
  https://raw.githubusercontent.com/xykong/flux-markdown/master/appcast.xml \
  -o "$evidence_dir/appcast-public.xml"
cmp appcast.xml "$evidence_dir/appcast-public.xml"
```

核对 API 中 `draft=false`、`prerelease=false`、正确标签与附件 digest；最新版状态按
本次发布意图检查。Sparkle 的版本/build、URL、长度和签名须指向同一个 DMG。
使用包内公钥进行签名校验，或记录等价可靠证据；不要读取或输出私钥。

查看公开 Sparkle `description` 的实际 HTML：完整 `@用户名` 在正确条目内，个人主页
和 issue 链接可点击。不要以 GitHub Release 已改好推断自动更新提示也改好了。

若出现缓存或 504，保留失败响应、时间和已成功的路径。固定提交 URL、公开 API 或
另一下载路径可帮助区分原因，但还需回读实际默认 feed/下载路径。不要不停修改标签、
重上传相同附件或留下临时缓存参数，来代替对原路径的验收。

## E. 生成、压缩和发布宣传图

将核对过的 prompt 保存到本版 `docs/release/artwork/` 文件，然后执行：

```bash
set -euo pipefail
artwork_dir="build/release-artwork-$release_version"
mkdir -p "$artwork_dir"
animal-mediakit --json generate image "$(cat "docs/release/artwork/$release_tag-prompt.txt")" \
  --model gpt-image-2.5-flare --size 1536x1024 --quality high --output-format png \
  -o "$artwork_dir/original.png" > "$artwork_dir/generate.json"
```

先查看原图，再从无损缩放结果生成 WebP，避免反复压缩已有 WebP：

```bash
set -euo pipefail
animal-mediakit image resize "$artwork_dir/original.png" \
  --width 1200 --height 800 -o "$artwork_dir/resized.png"
animal-mediakit image compress "$artwork_dir/resized.png" --quality 82 \
  -o "$artwork_dir/flux-markdown-$release_tag-celebration.webp"
file "$artwork_dir/flux-markdown-$release_tag-celebration.webp"
wc -c "$artwork_dir/flux-markdown-$release_tag-celebration.webp"
shasum -a 256 "$artwork_dir/flux-markdown-$release_tag-celebration.webp"
```

按 100–200 KB 目标调整质量，必须重新查看最终压缩图。模型不可用时记录真实替代方案。
确认后上传：

```bash
set -euo pipefail
gh release upload "$release_tag" "$artwork_dir/flux-markdown-$release_tag-celebration.webp"
```

使用下面 F 节的正文快照/比较/独立 notes 文件流程，在原正文顶部插入图片 Markdown。
首次使用 `flux-markdown-v<VERSION>-celebration.webp`；新图用新文件名，不覆盖旧图。
不要用原始 PNG、不动 manifest 绑定 notes、DMG 或 appcast。

从该公开 URL 重新下载并与本地比较，核对 MIME、1200×800、字节数和哈希。
浏览器打开 Release 页面，确认图片实际显示，检查截图。图片 `naturalWidth=0`、
破图、超时或浏览器不可用都算待验收；附件下载成功不能把这一项自动打勾。

## F. 已发布正文或致谢纠错

先明确修正范围；同一个用户变更要同步检查 CHANGELOG、Release 和 Sparkle。
历史任务列出所有版本与作者依据，逐条处理，不推断不存在的 issue/版本关系。
每一条署名移入真实的对应功能/修复条目，不创建统一名单。

下面示例只准备当前 `.version` 的纠错工作区。旧版本应明确设置 `target_version`，
不改 `.version`；每个版本独立快照。

```bash
set -euo pipefail
target_version=$(cat .version)
target_tag="v$target_version"
mkdir -p build
correction_dir=$(mktemp -d "$PWD/build/release-correction-$target_version.XXXXXX")
gh api "repos/xykong/flux-markdown/releases/tags/$target_tag" > "$correction_dir/release-before.json"
cp appcast.xml "$correction_dir/appcast-before.xml"
cp CHANGELOG.md "$correction_dir/changelog-before.md"
python3 - "$correction_dir" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
release = json.loads((root / 'release-before.json').read_text())
(root / 'notes-after.md').write_text(release['body'] or '')
PY
```

编辑该版本 CHANGELOG 条目和 `notes-after.md`，保留宣传图、其他正文及所有既有署名。
署名来源是 issue 作者时写清反馈；实现贡献者另保留 PR/实现链接。
对于重复版本标题，按具体功能条目定位；不要简单取最后一个同名版本段落。

编辑 appcast 时，通过 XML 解析定位**唯一**目标版本，只替换其 description，HTML
内容作为数据读取。不要调用签名生成器重新生成历史条目，也不要覆盖全部正文来补一个名字。
修改后执行不变性检查（允许当前目标的 description 变化，其余整棵 XML 不变）：

```bash
set -euo pipefail
python3 - "$correction_dir/appcast-before.xml" appcast.xml "$target_version" <<'PY'
import sys, xml.etree.ElementTree as ET
before, after = (ET.parse(p).getroot() for p in sys.argv[1:3])
ns = {'s': 'http://www.andymatuschak.org/xml-namespaces/sparkle'}
def target(root):
    items = [i for i in root.findall('./channel/item')
             if i.findtext('s:shortVersionString', namespaces=ns) == sys.argv[3]]
    assert len(items) == 1, 'Expected exactly one existing target version'
    return items[0].find('description')
old, new = target(before), target(after)
assert old is not None and new is not None
new.text = old.text
assert ET.tostring(before) == ET.tostring(after), 'Non-target description or metadata changed'
print('PASS: only the target description may differ')
PY
```

不存在历史 item 时记录缺项，不能制造下载签名。一次修正多个版本时为明确列出的
目标集合使用相同不变性原则，并保留每个版本的前后记录。

发布正文前再次读取，拒绝覆盖并发修改；生成结构化 payload 后只更新 body：

```bash
(
set -euo pipefail
gh api "repos/xykong/flux-markdown/releases/tags/$target_tag" > "$correction_dir/release-current.json"
python3 - "$correction_dir" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
old = json.loads((root / 'release-before.json').read_text())
current = json.loads((root / 'release-current.json').read_text())
assert current['body'] == old['body'], 'Concurrent body edit: merge before publishing'
for field in ['id', 'tag_name', 'target_commitish', 'name', 'draft', 'prerelease', 'published_at']:
    assert current[field] == old[field], field
def assets(release):
    return [{k: a.get(k) for k in ['id', 'name', 'size', 'digest']} for a in release['assets']]
assert assets(current) == assets(old), 'Assets changed: review before publishing'
(root / 'payload.json').write_text(json.dumps({'body': (root / 'notes-after.md').read_text()}))
PY
release_id=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' "$correction_dir/release-before.json")
gh api --method PATCH "repos/xykong/flux-markdown/releases/$release_id" --input "$correction_dir/payload.json"
gh api "repos/xykong/flux-markdown/releases/$release_id" > "$correction_dir/release-after.json"
python3 - "$correction_dir" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
old = json.loads((root / 'release-before.json').read_text())
new = json.loads((root / 'release-after.json').read_text())
assert new['body'] == (root / 'notes-after.md').read_text()
for field in ['tag_name', 'target_commitish', 'name', 'draft', 'prerelease', 'published_at']:
    assert new[field] == old[field], field
def assets(release):
    return [{k: a.get(k) for k in ['id', 'name', 'size', 'digest']} for a in release['assets']]
assert assets(new) == assets(old)
print('PASS: body read back exactly; release metadata and assets unchanged')
PY
)
```

只提交本次 CHANGELOG、appcast、流程/验证记录，直接推送 master。回读实际公共 feed，
验证完整用户名、HTML 链接及对应条目，保留默认 URL 的验证证据。不得改写
`release_notes_tmp.md`、manifest、DMG、源码包或签名，也不运行 `make release`。

## G. 中断恢复

| 现场 | 处理 |
| --- | --- |
| 已有版本/标签，准备失败且尚未发布附件 | 确认 notes、标签版本及 build inputs 未变化，用下方 resume；不重新 bump |
| GitHub/Sparkle 已成功，Homebrew 失败或退出 2 | 只完成 C 节的 tap 提交/推送/远端比对，再独立核对已成功渠道 |
| 缺少签名工具或密钥 | 修复实际签名条件；不跳过 Sparkle 后宣布成功 |
| notes 或附件与 manifest 不一致 | 保留现场并调查；不重写 manifest 让错误产物通过 |
| 已公开附件不一致 | 停止，报告具体差异；不覆盖附件或删除标签重来 |
| CI 依赖下载失败 | 读取日志；可针对失败 job 重跑并保留历史。未执行的测试不能算通过 |
| CDN/下载/图片显示仍失败 | 分开记录已发布、已下载、已渲染状态；恢复后补验收记录 |

```bash
set -euo pipefail
RELEASE_REMOTE_BUILD=1 RELEASE_PREPARE_ONLY=1 ./scripts/release.sh --resume
```

只在“准备失败且未发布附件”的条件下使用上述命令。对于发布重试，先检查
`publish-release.sh` 的实际调用：它仍会调用 appcast 生成器，已有版本可能触发替换
询问。不要为补一个渠道自动确认重签、重建或覆盖已成功阶段；按失败阶段单独恢复。

## H. 发布记录与 issue 收尾

从 [发布记录模板](RELEASE_RECORD_TEMPLATE.md) 创建本版记录，逐项填写实际证据；
不要预填“通过”。提交 prompt、记录与相关正文修改，保留 ignored 目录内的原始证据。

修复与发布验收确认后，用 issue 原语言准备回复文件，再执行：

```bash
set -euo pipefail
gh issue edit "$issue_number" --add-label done
gh issue comment "$issue_number" --body-file "$evidence_dir/issue-reply.md"
gh issue view "$issue_number" --json state,labels,comments
```

回复包含版本和具体修复、Homebrew 更新命令、DMG/Release 链接及真实限制。
已解决 issue 不主动关闭；调查工具/未确认修复不标 done。重复执行前检查是否已回复，
避免重复留言。

交付时列明已完成与未完成项。脚本成功、附件公开、图片上传和最终验收是不同状态。
任何必要步骤仍未验证，都不能报告“所有恢复、纠错、验证已完成”。

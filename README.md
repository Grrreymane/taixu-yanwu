# 太虚演武 · 符华

Godot 4.7.2 制作的 2.5D 横版格斗同人游戏，可在浏览器运行。当前包含六场「识境演武」试炼、强化构筑、分支剧情，以及与识之律者的自由对练。

## 文件入口

| 要做的事 | 位置 |
| --- | --- |
| 编辑当前剧情 | [识境演武_剧情重写完整版.md](docs/story/识境演武_剧情重写完整版.md) |
| 查看旧稿和原件 | [旧稿归档](docs/story/archive/) |
| 打开 Godot 工程 | `project.godot` |
| 启动网页 / 重新导出 | `启动网页试玩.cmd` / `重新导出网页.cmd` |
| 修改游戏逻辑与画面 | `scripts/`、`shaders/` |
| 角色、动作、场景、声音 | `assets/` |
| 规则与行为测试 | `tests/*_suite.gd` |
| 浏览器操作检查 / 画面探针 | `tests/browser/` / `tests/probes/` |
| 独立检查 / 资源生成 / 剧情导入 | `tools/diagnostics/` / `tools/asset-builders/` / `tools/story/` |
| 网页成品 / 截图 / 检查结果 | `build/web/` / `build/screenshots/` / `build/reports/` |

完整导航见 [目录说明](docs/project-layout.txt)。先前的详细移植记录保存在 [历史开发说明](docs/archive/README-wardrobe-grid-1.md)，其中的功能状态和旧路径以当时版本为准。

## 当前内容

| 装甲 | 外观 |
| --- | --- |
| 云墨丹心 | 原装、太虚仙忆 |
| 炽翎 | 原装、火与剑 |
| 白夜执事 | 原装、红叶知秋、春风之旅、玄衣素裳、黑执事 |
| 影骑士·月轮 | 原装、血月魔影 |
| 雾都迅羽 | 原装 |

五套装甲、十二套外观。首页头像按两行排列，没有横向滚动条；拖动角色可旋转，双击复位。「招式说明」介绍所选装甲的技能。外观共用对应装甲的战斗规则，选择会保存。

试炼前五场挑战幻身，每场后从三项强化中选一项，第六场挑战小识本人。十二种强化形成不同组合与剧情路线。首次通关解锁多选规矩；自由对练可以切换木人模式。战斗包含轻重连招、闪避、极限防御、追击、架势击破、必杀演出与 K.O. 收尾。

| 操作 | 按键 |
| --- | --- |
| 移动 | A / D 或方向键 |
| 轻击 / 重击 | J / K |
| 装甲技能 / 必杀 | E / Q |
| 格挡与极限防御 | L |
| 闪避 | 空格 |
| 木人切换（自由对练） | T |
| 选择强化 | 1 / 2 / 3，或点击卡片 |
| 暂停 / 音乐 / 战斗语音 | Esc / M / V |
| 对话显示全文或下一句 | Enter、空格或点击 |
| 跳过当前剧情段 | Esc |

画面按钮也可点击或触控。试炼不能关闭敌人 AI。通用对白语气声保持关闭；战斗出招、受击、必杀等使用已有中配资源。

## 当前剧情与编辑方式

当前版本为 `story-rewrite-1`，来自用户提供的完整重写稿：60 个场段、435 条编号正文、18 条无编号场景或动作描述。正文、标点、编号和发言人原样保留；旁白、符华心想、符华回忆和程立雪分别显示。

- 开场使用 A01 / A02，通关后的部分重访使用 A07；多重规矩接 A06。
- 强化对白优先级为 C 组合、尚未播放过的 D 转向、B 单卡。第三次强化之后插入 J01，第五次之后接对应 E 决战段。
- 胜利按 F 路线进入 I00 揭牌、I01 面馆前后文及路线回应，再进入 I02 云吞面与程立雪回忆。
- 失败仅播放对应 G 段，不提前揭牌或进入面馆尾声；H 段保留为备用。

山场继续使用原角色动作和固定对话镜头；面馆与厨房回忆采用静态背景。新增场景图由内置 image_gen 生成，来源与完整提示词记录在 [assets/story/source.json](assets/story/source.json)，不标为原游戏资源。这里没有新增可自由探索的城镇，也没有程立雪的可玩模型。

今后只编辑 `docs/story/识境演武_剧情重写完整版.md`，再在仓库根目录运行：

```powershell
python tools/story/import_story.py
python tools/story/import_story.py --check
python -m unittest discover -s tests -p story_source_import_test.py
```

导入器生成 `scripts/data/sentience_story_scenes.json`。剧情选择逻辑在 `scripts/sentience_story.gd`，数据读取在 `scripts/sentience_dialogue.gd`，展示在 `scripts/story_presentation.gd`。改变章节编号或路由结构时，应同步调整选择逻辑和测试。旧稿及工作区原件保存在 `docs/story/archive/`，不再作为活跃输入。

## 克隆、运行与导出

普通 Git 克隆即可取得源码与运行资源，无需 Git LFS。安装 **Godot 4.7.2**、同版本官方导出模板和 **Node.js**。游戏运行不依赖 Unity、原游戏客户端或提取工具。

```powershell
git clone https://github.com/Grrreymane/taixu-yanwu.git
cd taixu-yanwu
.\build-web.ps1 -GodotPath 'C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe'
.\start-web.ps1
```

路径请替换为自己的 Godot。脚本也支持 `GODOT_BIN` 或 PATH 中的 `godot` / `godot4`，并兼容本机原 `../tools/godot/` 目录。配置好后可使用两个 `.cmd` 入口。

导出采用 Compatibility 渲染器与无线程 Web 模板。使用独立模板目录时，可传 `-WebTemplatesPath` 或设置 `GODOT_WEB_TEMPLATES`，目录应包含 `web_nothreads_debug.zip`、`web_nothreads_release.zip`。编辑器旁的 `web-templates` 目录会自动识别。`-CheckOnly` 可检查工具路径；机器模板路径仅在导出期间使用，结束后恢复预设。

网页导出到 `build/web/`，通过本地 HTTP 服务访问 <http://127.0.0.1:4187/>，不要直接双击 `index.html`。跨平台可运行 `node server.mjs`。当前服务仅监听本机。

## 验证

将下列 `Godot` 替换为编辑器命令或完整路径：

```powershell
Godot --headless --path . --script tests/story_rewrite_suite.gd
Godot --headless --path . --script tests/story_rewrite_presentation_suite.gd
Godot --headless --path . --script tests/reward_story_suite.gd
Godot --headless --path . --script tests/story_camera_continuity_suite.gd
node tests/browser/story-rewrite-browser.cjs
```

浏览器检查使用开发机现有 Playwright 路径；换环境时需调整脚本依赖位置。部分原资产审计需要本机提取备份，它们不属于普通运行依赖。

`.godot/`、`build/`、日志和缓存不提交 Git。工作区外层的旧工程、原模型、提取记录、编辑器与演示视频保留原位，目录导航见工作区的 `项目入口.txt`。

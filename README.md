# 太虚演武 · 符华

Godot 4.7.2 制作的 2.5D 横版格斗同人游戏，可在浏览器运行。当前包含六场「识境演武」试炼、强化构筑、分支剧情，以及与识之律者的自由对练。

本项目为非官方同人作品，与米哈游无隶属或官方认可关系。原游戏资源、项目制作内容及第三方参考分别列于 [来源与致谢](CREDITS.md)；权利范围见 [LICENSE](LICENSE)。仓库公开不代表第三方游戏资源获得了新的使用许可。

## 网页试玩

[点击进入识境演武](https://grrreymane.github.io/taixu-yanwu/)（建议桌面浏览器和键盘）。首次进入需要下载约 120 MB 游戏文件，请等待加载完成。进度保存在当前浏览器；清理网站数据或换浏览器不会自动同步存档。

发布方法见 [网页部署说明](docs/web-publishing.md)。

## 文件入口

| 要做的事 | 位置 |
| --- | --- |
| 编辑当前剧情 | [识境演武_精简对白.md](docs/story/识境演武_精简对白.md) |
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

试炼前五场挑战幻身，每场后从三项强化中选一项，第六场挑战小识本人。十八种通用强化形成不同组合与剧情路线；每套装甲各有三种核心打法、六项专属强化，共十五条核心、三十张专属卡。首次通关解锁多选规矩；自由对练可以切换木人模式和双方无限血量。战斗包含轻重连招、闪避、极限防御、追击、架势击破、必杀演出与 K.O. 收尾。

每套装甲的新试炼都在开局选择本轮核心，皮肤共用所属装甲的机制。按 1 / 2 / 3、Tab + Enter 或点击选择，ESC 返回。核心与专属强化随试炼保存；已有试炼继续沿用原规则。

自由对练中点击「打法配置」或按 B，可随时更换三种核心，独立勾选该核心的两项专属强化，或恢复「基础招式」。配置时暂停战斗；「应用并重置对练」重置双方生命、能量、冷却和场上效果，保留木人模式及无限血量设置。取消返回原战斗；大招、K.O. 和结算中也可打开。各装甲的配置单独保存在本地，不改变试炼存档和排行榜成绩。

对练右侧的「无限能量」可随时开关，开启后玩家 SP 保持 100，必杀与分支不消耗 SP；大招持续时间、技能冷却和连招限制保持原样。打法配置中的「小识招路」可选剑连斩后撤、枪长距突刺或链刃两段横扫，复用试炼关底的完整招路与半血入梦。应用后重置本场对练，保留核心、专属强化和所有对练开关。能量开关与招路会随本地偏好保存，切换装甲后仍保留，进入试炼时无限能量自动禁用。

| 装甲 | 三条核心 | 操作与资源 |
| --- | --- | --- |
| 云墨丹心 | 阴阳相生 / 三阳回气 / 三阴破阵 | J 阳、K 阴，三层后 E；混色聚怪、三阳回能、三阴易伤破守 |
| 炽翎 | 神通流转 / 离火相续 / 丹心蓄势 | E 换拳腿，不同分支攒神通；强力换式、挂火引爆或留神通开 Q |
| 影骑士·月轮 | 月食续战 / 断海鸣雷 / 裂空破军 | SP 换月食续时、E 开引雷后 J/K 触发、月食 E 接强化 K |
| 雾都迅羽 | 雷闪疾行 / 霹雳连环 / 惊雷破空 | E→K 重置 E、三层蓄雷 K 群攻、成功闪避后 70 SP 开 Q |

这些是结合原机制的横版改编，不等于原游戏完整技能表。原资料与改编边界见 [装甲机制记录](docs/armor-paths-reference.txt)。白夜保留以下打法：

| 核心 | 操作变化 | 两项专属强化 |
| --- | --- | --- |
| 防反破阵 | 极限防御后 K 击退对手，撞到后排时产生一次碰撞打击 | 隔山打牛：最多撞到两名后排；追身寸劲：防反 K 命中后可无视冷却接一次原版 E |
| 闪避续招 | 成功闪过攻击后 1.6 秒内，J 续接中断连招的下一段；空闪不触发 | 回身破守：可用穿过格挡的 K 收招；踏风连步：恢复一次闪避并将续招窗口延长至 2.4 秒，每 2 秒限一次 |
| 连势快攻 | J 第三段命中后可无视冷却接 E，再接 J；一串连击限一次，断连恢复 | 寸劲开门：连势 E 末段打破格挡；拳脚相续：E 后 J 从第二段继续，也可接 K |

奖励池只加入所选核心对应的两张专属卡。仍有未取得、且未被本次换选排除的专属卡时，至少提供一张；其余位置保留通用强化。接招窗口内 E 按钮会亮起提示。专属卡计入现有剧情路线与结局判断，不额外添加新对白。

选择核心的新试炼中，小识会从三套招路中选择一套：剑连斩后撤、长枪控距且突刺落空后留下破绽、链刃两段横扫且第二段为红光。第五关奖励页的「i」中可查看招路，半血入梦仍保留。种子、核心与招路在重试和续档时保持一致。使用现有原版动作、声音、特效与运镜；碰撞使用现有命中效果，同屏敌人数不增加。

强化分为防反、闪避、连击、必杀四类，另有独立补给。每类凑齐 2 项、3 项分别激活额外效果；五次选择可以集中一类，也可搭配两类。新增强化包括闪避后的下一招增伤、防反追击与三连末段缩短技能冷却、破架势后的增伤、必杀后的持续输出和击败回复。卡片常驻名称、效果与选取操作，三项使用同样的外观；组合规则收进「i」详情，支持鼠标、键盘和触控。候选兼顾已选打法与其他路线，低血量时优先提供可用的恢复选项。每轮共有 **2 次换选**，每次替换当前三张卡；次数和卡片随本地存档保存。

只有一名对手的开场，统一为符华在左、对手在右，双方相向；多人包夹仍保留原阵型，战斗中可以正常换边。

每轮试炼会重新组合 12 种阵型、3 种节奏规则与 5 种本场加试。前盾后枪、两翼夹击、近身压制等配置会改变敌人的站位、武器与收招行为；招式的预警时间保留。最终小识有 3 种武器起手顺序，第二阶段仍会使用必杀。加试为可选目标，获胜并达成后额外奖励 8 SP 与 75 分；失败重试沿用本轮阵型和目标，不会重新抽取。

第三场起，精英会随机采用坚守、追身或连锋招路：蓄势时抵抗普攻、连打后闪身反击，或用原有枪与链刃动作追加第二段。后半程伤害与进攻压力逐步提高，小识会交替蓄势、武器连段和半血入梦。黄光蓄势可用 K / E、极限防御或架势击破打断，红光使用闪避；防反后的追击窗口保留。奖励页会预告下一场招路。全程敌人总生命仍为 1000。

五套装甲的必杀按原生动作重编近景、动作切镜、命中与回场镜头。特效使用已有原生贴图、网格与可用曲线，空间发射轨迹适配横版战场；并非完整移植 Unity 的全部粒子组件或原版摄像机时间轴。人物近景会暂时隐藏对手，动作镜头恢复显示；镜头、特效与边缘构图都随战斗时间暂停。

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

## 通关计时与本地存档

试炼界面显示本轮累计战斗用时，结算显示同一时间及本地最快纪录。计时采用真实经过时间，包含大招和命中停顿；剧情、选强化、开场倒计时、暂停、页面失焦和结束演出不计。失败重试保留已经花费的时间。自由对练不产生通关计时纪录。

战斗中每两秒自动保存，开关、选强化、暂停、返回主页与页面离开时也会保存。主页的「继续试炼」恢复原装甲、皮肤、规矩、种子、关卡、强化与累计用时，从当前关卡开场重打；奖励页则恢复原来的三张卡，不重新抽取或重复发放补给。新试炼替换未完成的一轮，自由对练保留试炼存档。已有通关解锁、称号与最高分兼容保留。

白夜选核心的新试炼使用 `trial-2026-11-03-night-paths` 规则，其余新试炼沿用 `trial-2026-10-31-builds`。已有未结束试炼保留原来的规则、强化与敌人招路；开始白夜新试炼即可体验核心打法。

网页版存档保存在同一浏览器、同一网站的本地存储中；桌面版使用 `user://`。存档包含版本号和上一份有效备份，写入失败会在首页提示。最近 20 次通关记录保留毫秒用时、装甲、皮肤、规矩、种子、重试/续玩次数与规则版本。直接打开试玩链接可保存本地纪录；在 AIWanna 内新开试炼并完成六关，可参与平台排行榜。

## 当前剧情与编辑方式

当前版本为 `story-compact-1`，以工作区根目录《识境演武_角色语气重写_v3》里手改的“对白重写 v4”为底稿精简，补齐六项新强化。新稿有 66 个场段、131 条编号文本和 2 处回忆转场，部分场段保留备用。导入时按新稿保留正文、标点、编号和发言人，编辑备注不进入游戏。原手改文件不覆盖。

- 开场使用 A01 / A02，通关后的部分重访使用 A07；多重规矩接 A06。
- 十八项强化各有两句专属交流；C 组合、尚未播放过的 D 转向优先替换 B 单卡，均只播两句。第五次选卡后另接两句 E 决战对白，中场 J01 不自动追加。
- 首次开场六句，重玩开场四句。胜利按 F 路线进入 I00 山门、I01 点面和 I02 回忆，共 15 条（含两处转场）；等面长谈保留备用。立雪以符华的内心回忆出现，没有新增立雪台词。
- 失败仅播放对应 G 段，不提前揭牌或进入面馆尾声；H 段保留为备用。

山场继续使用原角色动作和固定对话镜头；面馆与厨房回忆采用静态背景。新增场景图由内置 image_gen 生成，来源与完整提示词记录在 [assets/story/source.json](assets/story/source.json)，不标为原游戏资源。这里没有新增可自由探索的城镇，也没有程立雪的可玩模型。

当前编辑入口是 `docs/story/识境演武_精简对白.md`，工作区根目录也放有同名副本便于修改。修改后将稿件同步到此入口，再在仓库根目录运行：

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

网页在加载遮罩下预先绘制战斗特效、凤凰骨骼模型和镜头叠加层，避免首次出招时才编译着色器。预热使用实际游戏视口，结束后移除全部样本，不改变战斗时间、伤害或特效预算。这个处理针对 Compatibility 的首次编译停顿；角色首次切换的资源载入和低性能设备的持续渲染开销仍需单独衡量。参见 [Godot 的编译卡顿说明](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html)。

装甲选择保留最近使用的四套非当前外观，回切时复用完整模型、骨骼、材质和动作资源，并清除上一轮的受击、表情和爆发状态。超过上限按最近使用顺序释放，避免浏览全部皮肤后一直占用内存。材质检查直接读取网格格式标记，避免为了查找第二套 UV 而复制整份顶点数据；完全隐藏的辅助表面不再使用光照计算，加载阶段也预热隐藏材质和迅羽的半透明材质。不降低可见贴图、模型、阴影或特效质量。多敌人的头顶血条由一个表面同时绘制边框、底色和剩余生命，避免独立底板盖住填充条。

战斗动作每帧只采样一次原版轨道；`seek(..., true)` 已立即更新姿势，后面无需再 `advance(0)`，参见 [AnimationPlayer 文档](https://docs.godotengine.org/en/stable/classes/class_animationplayer.html#class-animationplayer-method-seek)。面部光照只更新使用它的脸部材质，受击闪光、主光方向和眼口贴图在值改变时更新。倒地演出结束且已隐藏的敌人停止骨骼采样。原版粒子的颜色键预先解析，双曲线直接读取两组原始键；保持曲线、颜色、数量、生命周期和贴图不变。这些改动不降低渲染分辨率、阴影质量或动画更新频率。

网页导出到 `build/web/`，通过本地 HTTP 服务访问 <http://127.0.0.1:4187/>，不要直接双击 `index.html`。跨平台可运行 `node server.mjs`。当前服务仅监听本机。

## 验证

将下列 `Godot` 替换为编辑器命令或完整路径：

```powershell
Godot --headless --path . --script tests/story_rewrite_suite.gd
Godot --headless --path . --script tests/story_rewrite_presentation_suite.gd
Godot --headless --path . --script tests/reward_story_suite.gd
Godot --headless --path . --script tests/story_camera_continuity_suite.gd
Godot --headless --path . --script tests/duel_spawn_suite.gd
Godot --headless --path . --script tests/run_save_suite.gd
Godot --headless --path . --script tests/run_save_flow_suite.gd
Godot --headless --path . --script tests/run_save_hud_suite.gd
node tests/browser/story-rewrite-browser.cjs
node tests/browser/run-save-browser.cjs
node tests/browser/frame-pacing-browser.cjs sample
Godot --headless --path . --script tests/actor_cache_suite.gd
Godot --path . --script tests/probes/group_health_pixels.gd
node tests/browser/armor-switch-performance.cjs sample
Godot --headless --path . --script tests/night_paths_suite.gd
Godot --headless --path . --script tests/night_paths_playthrough_suite.gd
node tests/browser/night-paths-browser.cjs
Godot --headless --path . --script tests/native_particle_sampling_suite.gd
Godot --headless --path . --script tests/expired_enemy_update_suite.gd
Godot --headless --path . --script tests/probes/combat_load_probe.gd -- sample
node tests/browser/group-frame-pacing-browser.cjs sample
```

帧时间检查分别记录首次/再次大招与近身连打的均值、最慢帧、P95/P99 和阻塞的 WebGL 调用，结果写入 `build/frame-pacing-sample.json`。使用新浏览器上下文，支持 `GODOT_TEST_URL`、`PERF_STYLES`（逗号分隔装甲 ID）、`PERF_WIDTH`、`PERF_HEIGHT`、`PERF_DPR`。测量时不要同时运行其他渲染测试；不同硬件上的结果不能直接比较。

装甲切换检查记录首次和再次选择的耗时、最慢帧及 WebGL 阻塞，支持 `GODOT_TEST_URL`，结果写入 `build/armor-switch-sample.json`。血条检查需要实际图形渲染，比较两种分辨率、多个站位和重复刷怪后的 36 个填充比例与真实生命值；报告和截图存入 `build/`。

战斗压力检查可设置 `PERF_CPU_RATE=4`，通过浏览器减慢 CPU 执行以放大瓶颈；该模式是人工压力条件，不代表某台手机的实际帧率。群战脚本通过普通操作打到第四关，记录单敌、多敌和大招的帧时间。`combat_load_probe.gd` 在隔离存档的确定性场景中采集五套装甲、三个敌人的处理耗时、骨骼和特效数量；改动前后可用 `python tests/compare_combat_evidence.py build/combat-evidence-before.json build/combat-evidence-after.json` 比较行为与姿势。

白夜规则检查覆盖核心触发与消耗、六项强化、原版动作标识、存档与换选、三套小识招路，以及三种核心分别挑战三套招路的九轮完整试炼。网页检查使用新浏览器存档，通过普通输入验证三种开局、过关选卡和刷新续档。性能探针可追加核心参数，例如 `combat_load_probe.gd -- night-chain chain`，测量白夜携带该核心及两项专属强化时的三敌人场景。

浏览器检查可通过 `npm install --no-save playwright` 安装依赖，默认使用本机 Microsoft Edge。也可设置 `PLAYWRIGHT_MODULE` 指向已有 Playwright 模块目录；已有 Codex 运行环境会自动按当前用户目录查找。无需修改测试脚本中的个人路径。部分原资产审计使用工程父目录下的 `hi3-fuhua-extract/` 提取备份，它们不属于普通运行依赖。

`.godot/`、`build/`、日志和缓存不提交 Git。工作区外层的旧工程、原模型、提取记录、编辑器与演示视频保留原位，目录导航见工作区的 `项目入口.txt`。

## AIWanna 通关榜

在 [AIWanna](https://www.aiwanna.games/games/game-3ae8aa2793124454) 内新开试炼，完整打完六关后自动提交累计战斗用时（毫秒，越短越好）。失败重试时间累计，剧情、选强化和暂停不计时。所有装甲与规矩共榜。续档、自由对练和站外独立试玩不上榜；平台单局凭证须在开局后两小时内结算。

首页及结算后点击“通关榜”查看前十与个人最佳；网络失败可重试提交，不影响本地存档。当前为客户端报分的休闲榜，不能视为经过服务端验算的竞技成绩。

接入使用原生浏览器消息握手和 REST，令牌只保存在内存。协议检查：`node tests/web/leaderboard-client.cjs`（使用模拟接口，不写真实榜单）。

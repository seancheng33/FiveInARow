# 五子棋 Gomoku

Godot **4.2.2** 单机五子棋。双人对战、人机对战（三档难度）、AI 观战。
界面全部由容器布局驱动，窗口可自由缩放；AI 在后台线程思考，不会卡住界面。

## 运行

用 Godot 4.2.x 打开本目录的 `project.godot`，按 F5 即可。

或用命令行：

```bash
godot --path <本目录> 
```

## 操作

| 操作 | 说明 |
|---|---|
| 鼠标左键 | 落子，悬停会显示半透明预览 |
| 右侧栏 | 用时、手数、AI 实际层数、悔棋/重开/外观/返回都在这里 |
| 「外观主题」按钮 | 主菜单和对局右侧栏都有，点开弹出主题选择框，立即生效并记住 |
| `R` | 重新开始当前对局 |
| `U` | 悔棋（人机模式下会一次撤掉双方各一手） |
| `Esc` | 返回主菜单 |
| 结束面板 | 再来一局 / 悔棋 / 返回菜单 |

## 规则

- 15×15 棋盘，黑先，横竖斜任意方向**连续五子及以上**获胜（长连也算胜）。
- 棋盘下满且无人五连判平局。
- 采用无禁手规则：黑方不判三三、四四、长连禁手。若要做竞技连珠规则，只需在 `GameCore.place()`
  里增加禁手校验。

## 目录结构

```
project.godot            工程配置（960x740，canvas_items 拉伸；Ui 自动加载）
main_scene.tscn          入口场景，只挂一个 MainMenu 实例
scenes/
  main_menu.tscn         主菜单 + 难度选择面板（含层数下拉）
  theme_picker.tscn      外观主题弹窗（菜单与对局共用）
  board.tscn             对局界面（顶栏 / 棋盘 / 底栏 / 结束面板）
scripts/
  main_menu.gd           菜单逻辑：选模式 → 选难度 → 创建对局
  board.gd               对局控制器：输入守卫、AI 调度（后台线程）、界面刷新
  board_canvas.gd        棋盘绘制与坐标换算（只画不判）
  game_core.gd           纯规则层：落子、五连、平局、悔棋、快照（无渲染无输入）
  ai_base.gd             AI 基类：棋盘转换、候选点生成、落点评分
  random_ai.gd           简单：随机
  defensive_ai.gd        普通：一层启发（抢五连 / 堵五连 / 棋型评分）
  advanced_ai.gd         困难：Minimax + Alpha-Beta + 迭代加深 + 时间预算
  pattern_detector.gd    棋型识别（支持跳三、跳四）
  ui_palette.gd          五套界面配色的数据表（唯一配色来源）
  ui_skin.gd             外观单例 Ui：按配色构建 Theme / 棋盘样式 / 背景渐变
  theme_picker.gd        主题弹窗逻辑（颜色圆点 + 名称 + 描述 + 当前标记）
tests/                   功能测试与 GUI 驱动（不参与导出）
```

### 分层约定

- **规则**只写在 `game_core.gd`。它不依赖场景树，可以 `GameCore.new()` 直接构造来写单测。
- **绘制**只写在 `board_canvas.gd`，它拿 `GameCore` 引用读数据，不改数据。
- **流程**（谁该走、AI 什么时候动、面板什么时候弹）只写在 `board.gd`。
- AI 通过 `get_next_move(board_state: Array, player_type: int) -> Vector2i` 接收一份**快照**，
  不持有真实棋盘，因此可以在子线程里安全运行。

## 外观主题

主菜单和对局右侧栏都有「外观主题」按钮，点开是一个居中弹窗，5 套主题各一行（颜色圆点 + 名称 + 描述 +
当前标记），点一下立即换肤且不用关弹窗就能对比。选择存在 `user://settings.cfg`，下次启动沿用。

| 主题 | 界面 | 棋盘 | 气质 |
|---|---|---|---|
| 樱雾 Sakura Mist | 米白偏粉 · 桃粉强调 | 浅樱木色 · 大圆角 | 最柔最粉，长时间看不累 |
| 暖木 Warm Wood | 奶油底 · 珊瑚红 | 焦糖木面 + 胡桃木外框 | 像真实棋具，最耐看 |
| 莓夜 Berry Night | 深莓紫底 · 霓虹粉 | 暖米色「纸」 | 反差最大，适合做封面 |
| 和纸 Washi Beni | 米纸底 · 朱红 · 宋体 | 米黄纸感 · 直角细边 | 像装帧考究的棋谱 |
| 樱木 Sakura Wood | 樱雾的粉色界面 | 暖木的木质棋盘 | 粉色氛围 + 木质质感 |

实现方式：`ui_palette.gd` 只存颜色字符串，`ui_skin.gd`（自动加载单例 `Ui`）把它们编译成
`Theme` + `StyleBoxFlat`，并广播 `changed` 给棋盘画布和背景。加一套新主题只需要往
`ui_palette.gd` 的数组里加一条字典，不用改任何界面代码。

> 注意：外观脚本故意不写 `class_name` —— `Skin` 是 Godot 内置类名，会与原生类冲突。

## AI 三档

| 难度 | 实现 | 特点 |
|---|---|---|
| 简单 | `RandomAI` | 随机落子 |
| 普通 | `DefensiveAI` | 一层棋型评估：先抢自己的五连，再堵对手五连，其余按 `AIBase.score_move` 挑 |
| 困难 | `AdvancedAI` | 同一套棋型评估打底，再加迭代加深搜索，层数与时间预算由菜单下拉选择 |

三档共用同一个评估函数，只靠"有没有搜索、搜索多深"区分，强弱关系由结构保证。
实测（`tests/match_probe`，各 4~6 番）：困难 5:1 普通、困难 4:0 简单、普通 4:0 简单。

困难档的层数在「选择 AI 难度」面板里用下拉选，每档配了对应的思考预算（按实测填，不虚标）：

| 档位 | 预算 | 实测耗时 | 说明 |
|---|---|---|---|
| 2 层 | 150 ms | < 0.2 s | 秒回 |
| **3 层（默认）** | 600 ms | ≈ 0.4 s | 战术正确、节奏舒服 |
| 4 层 | 7 s | ≈ 6.1 s | 明显更强，每步要等几秒 |
| 5 层 | 17 s | ≈ 15.2 s | 极限档，慎用 |

为什么没有 6 层以上：`tests/depth_probe` 实测每多一层耗时约 ×6~8，6 层≈2 分钟、7 层≈12 分钟、
8 层≈1.5 小时。纯 GDScript 下这就是天花板，所以下拉只到 5 层。
搜索跑在子线程里，再慢也不会卡住界面（帧间隔稳定 17~18 ms）。

困难档搜索的几个要点（也是它不会卡死的原因）：

- 直接在扁平棋盘上 make/unmake，不再每个节点深拷贝整盘；
- 每个节点都检查时间预算，到点回退到上一层已完成的结果；
- 根节点用完整棋型评分排序、内部节点用邻接权重排序后截断宽度；
- 叶子评估把棋盘预先切成 88 条直线，单遍扫描计分。

## 测试

测试全部在 `tests/` 下，不参与导出。

```bash
# 功能测试（132 项断言：规则 / AI / 流程 / 计时 / 主题 / 界面结构）
godot --headless --path . res://tests/test_runner.tscn
# 退出码 0 = 全绿

# 真窗口交互 + 截图（截图写到 tests/shots/）
godot --path . res://tests/gui_driver.tscn

# 人机对战卡顿检测（记录帧间隔）
godot --path . res://tests/gui_ai_driver.tscn

# 逐主题截图（5 套各拍主菜单 / 对局 / 结束面板，写到 tests/shots/）
godot --path . res://tests/theme_shots.tscn

# 搜索深度极限实测（不同时间预算下能算到第几层）
godot --headless --path . res://tests/depth_probe.tscn

# 棋力对拼（可改 tests/match_probe.gd 里的局数与预算）
godot --headless --path . res://tests/match_probe.tscn

# 困难档根节点候选诊断（打印静态分 / 搜索值对照表）
godot --headless --path . res://tests/ai_debug.tscn
```

## 已知限制

- 仅在 Godot 4.2.2 / Windows x86_64 验证过；未测试移动端触摸输入（代码里没有 `InputEventScreenTouch`）。
- 和纸主题的衬线字体用 `SystemFont` 调用系统「宋体」，换到没有宋体的机器会回退到默认无衬线。
- 未做禁手规则、复盘回放、联网对战。双人对战入口已隐藏，代码路径保留，等联机做好再打开。
- 未打包 `.exe`：本机没有安装 4.2.2 导出模板。装上后 `export_presets.cfg` 里的
  `Windows Desktop` 预设可直接导出到 `dist/`。

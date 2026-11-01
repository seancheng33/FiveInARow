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
project.godot            工程配置（960x740，canvas_items 拉伸，全局主题）
main_scene.tscn          入口场景，只挂一个 MainMenu 实例
assets/ui_theme.tres     全局主题（按钮/面板样式、默认字号）
scenes/
  main_menu.tscn         主菜单 + 难度选择面板
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
tests/                   功能测试与 GUI 驱动（不参与导出）
```

### 分层约定

- **规则**只写在 `game_core.gd`。它不依赖场景树，可以 `GameCore.new()` 直接构造来写单测。
- **绘制**只写在 `board_canvas.gd`，它拿 `GameCore` 引用读数据，不改数据。
- **流程**（谁该走、AI 什么时候动、面板什么时候弹）只写在 `board.gd`。
- AI 通过 `get_next_move(board_state: Array, player_type: int) -> Vector2i` 接收一份**快照**，
  不持有真实棋盘，因此可以在子线程里安全运行。

## AI 三档

| 难度 | 实现 | 特点 |
|---|---|---|
| 简单 | `RandomAI` | 随机落子 |
| 普通 | `DefensiveAI` | 一层棋型评估：先抢自己的五连，再堵对手五连，其余按 `AIBase.score_move` 挑 |
| 困难 | `AdvancedAI` | 同一套棋型评估打底，再加迭代加深搜索，单次思考 650ms 预算，深度菜单可调 1~5 |

三档共用同一个评估函数，只靠"有没有搜索、搜索多深"区分，强弱关系由结构保证。
实测（`tests/match_probe`，各 4~6 番）：困难 5:1 普通、困难 4:0 简单、普通 4:0 简单。

困难档单步约 0.74~0.78 秒，但**计算在子线程里跑**，界面全程保持 60 fps。

困难档搜索的几个要点（也是它不会卡死的原因）：

- 直接在扁平棋盘上 make/unmake，不再每个节点深拷贝整盘；
- 每个节点都检查时间预算，到点回退到上一层已完成的结果；
- 根节点用完整棋型评分排序、内部节点用邻接权重排序后截断宽度；
- 叶子评估把棋盘预先切成 88 条直线，单遍扫描计分。

## 测试

测试全部在 `tests/` 下，不参与导出。

```bash
# 功能测试（105 项断言：规则 / AI / 流程 / 界面结构）
godot --headless --path . res://tests/test_runner.tscn
# 退出码 0 = 全绿

# 真窗口交互 + 截图（截图写到 tests/shots/）
godot --path . res://tests/gui_driver.tscn

# 人机对战卡顿检测（记录帧间隔）
godot --path . res://tests/gui_ai_driver.tscn

# 棋力对拼（可改 tests/match_probe.gd 里的局数与预算）
godot --headless --path . res://tests/match_probe.tscn

# 困难档根节点候选诊断（打印静态分 / 搜索值对照表）
godot --headless --path . res://tests/ai_debug.tscn
```

## 已知限制

- 仅在 Godot 4.2.2 / Windows x86_64 验证过；未测试移动端触摸输入（代码里没有 `InputEventScreenTouch`）。
- 未做禁手规则、计时器、复盘回放、联网对战。
- 未打包 `.exe`：本机没有安装 4.2.2 导出模板。装上后 `export_presets.cfg` 里的
  `Windows Desktop` 预设可直接导出到 `dist/`。

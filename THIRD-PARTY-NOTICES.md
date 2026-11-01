# 第三方资源与许可

本项目在运行时会加载下列第三方资源。分发（包括打包成 exe 或 Web 版）时请一并保留本文件。

## 字体

**钟齐志莽行书 / Zhi Mang Xing Regular**
- 文件：`assets/fonts/ZhiMangXing-Regular.ttf`
- 用途：主菜单标题、对局结算大字（胜 / 负 / 平）
- 许可：SIL Open Font License 1.1（可免费商用、可嵌入、可再分发；不可单独售卖字体本身）
- 版权：Copyright 2018 The Zhi Mang Xing Project Authors
  (https://github.com/googlefonts/zhimangxing)
- 许可全文：`assets/fonts/OFL.txt`

## 图片

**主菜单山水背景**
- 文件：`assets/art/bg_shanshui.png`
- 来源：由 AI 图像模型生成，生成后经过程序化去水印与调色处理
- 许可：随本项目一同分发，无第三方版权限制

## 音效

- 文件：`assets/audio/*.wav`（落子、胜负、平局、按键共 6 个）
- 来源：本项目用 numpy 程序化合成（正弦波 + 噪声 + 包络 + 软限幅），未使用任何外部音效素材
- 许可：随本项目一同分发，无第三方版权限制

## 引擎

**Godot Engine 4.2.2**
- 许可：MIT License
- 游戏运行时包含 Godot 引擎代码，其版权声明见 https://godotengine.org/license

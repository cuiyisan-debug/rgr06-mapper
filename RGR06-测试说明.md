# RGR06 按键探针

本工具用于确认 RGR06 指环已经通过 Windows HID 层暴露了哪些可映射事件。

## 启动

双击 `rgr06-input-probe.ahk`，或运行：

```powershell
& 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' 'C:\Users\cuiyi\Documents\Codex\2026-05-27\windows-windows-rgr06\rgr06-input-probe.ahk'
```

## 测试顺序

启动后尽量不要使用电脑键盘，只对 RGR06 逐项执行：

1. 单击。
2. 双击。
3. 长按约 2 秒后松开。
4. 上滑、下滑、左滑、右滑。
5. 设备支持的其他触控或媒体操作。

列表会记录 Windows 收到的 `键名`、`VK` 与 `SC`。每次运行都会在当前目录生成 `rgr06-events-日期时间.csv` 日志。

## 图示动作的引导记录

根据设备说明图，推荐改用 `rgr06-guided-probe.ahk`。它会把物理动作标签与捕捉到的按键一起记录：

```powershell
& 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' 'C:\Users\cuiyi\Documents\Codex\2026-05-27\windows-windows-rgr06\rgr06-guided-probe.ahk'
```

在窗口中逐项选择动作并点击“开始记录该动作”，然后只对指环重复操作 3 次。需要记录的动作已经按说明图列入下拉框，包括滚轮、右侧键、左侧键和触摸板。

## 辅助检查

- `Ctrl+Alt+F8`：打开 AutoHotkey 自带的 `KeyHistory`，用于查看列表中没显示出的低级键盘事件。
- `Ctrl+Alt+F9`：清空界面列表，不删除 CSV 历史。
- `Ctrl+Alt+F12`：退出探针。

## 范围说明

该脚本能捕捉 RGR06 通过标准键盘或消费者控制 HID 接口输出的按键。它不会阻断原有动作，也不能单独识别“相同按键究竟来自指环还是实体键盘”。

若点击或滑动动作在本工具与 `KeyHistory` 中均没有出现，下一步应订阅设备私有 BLE Notify 特征 `f51c527c-79bb-70bb-8b42-d234b6818e38`，直接记录设备原始事件。

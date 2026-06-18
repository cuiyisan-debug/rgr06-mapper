# RGR06 Mapper 安装说明

此安装包包含 RGR06 Mapper 主程序、AutoHotInterception 依赖库和 Interception 键盘/鼠标过滤驱动安装器。

RGR06 Mapper 的用途是把乐奇眼镜配套的 RGR06 戒指改作 Windows 电脑端鼠标和快捷键控制器。

## 安装

1. 运行 `RGR06-Mapper-Setup-v0.19.exe`。
2. 按提示授予管理员权限。
3. 安装程序会复制文件并安装 Interception 驱动。
4. 安装完成后请重启电脑，驱动级输入过滤需要重启后稳定生效。

## 运行环境

- Windows 10/11 x64。
- 不需要单独安装 AutoHotkey。
- 需要安装 Interception 驱动，安装包已内置。
- AutoHotInterception 依赖 .NET Framework，Windows 10/11 通常已内置可用版本。

## 使用规范

- 请先完成 RGR06 与 Windows 的蓝牙配对。
- 程序启动后会常驻系统托盘，关闭设置窗口不会退出映射。
- 需要临时停用时，优先使用托盘菜单里的“暂停/继续映射”。
- 自定义快捷键请在设置窗口中选择“自定义按键”，再点击“录制”完成绑定。

## 卸载

可在 Windows“应用和功能”里卸载 RGR06 Mapper。卸载时会尝试执行 Interception 驱动卸载命令；卸载驱动后也建议重启电脑。

## 注意

Interception 是键盘/鼠标过滤驱动。若目标电脑上有安全软件或企业管控策略，可能会拦截驱动安装。

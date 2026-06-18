#Requires AutoHotkey v2.0
#SingleInstance Ignore
InstallKeybdHook
#UseHook
#include Lib\AutoHotInterception.ahk

; RGR06 Mapper - configurable Windows tray application for the Rokid control ring.
; Mapping is active immediately after launch when the Interception/AHI device
; path is available. Compatibility hotkeys stay disabled in production to avoid
; intercepting the built-in keyboard.

global AppName := "RGR06 Mapper"
global AppVersion := "0.19.0"
global ConfigDir := A_AppData "\RGR06 Mapper"
global ConfigPath := ConfigDir "\settings.ini"
global TouchpadScript := A_ScriptDir "\toggle-rgr06-touchpad.ps1"
global TouchpadStatusPath := ConfigDir "\touchpad-status.txt"
global MappingActive := true
global PrefixUntil := 0
global SuppressUpUntil := 0
global SuppressDownUntil := 0
global F2Triggered := false
global F3PulseCount := 0
global F3LastPulseAt := 0
global LastBrowserBackTick := 0
global UseAhiInput := false
global UseCompatHotkeys := false
global AHI := ""
global AhiTargetId := 0
global AhiPrefixUntil := 0
global AhiF3PulseCount := 0
global AhiF3LastPulseAt := 0
global SettingsGui := ""
global StatusLabel := ""
global StartupCheckbox := ""
global ActiveCheckbox := ""
global Controls := Map()
global RecordingGesture := ""
global RecordingPreviousActive := false
global RecordingCaptured := false
global RecordingHotkeys := []
global RecordingMods := Map("Ctrl", false, "Alt", false, "Shift", false, "Win", false)
global WM_INPUT := 0x00FF
global RID_INPUT := 0x10000003
global RIDI_DEVICENAME := 0x20000007
global RIDEV_INPUTSINK := 0x00000100
global RawHeaderSize := 8 + A_PtrSize * 2
global RawDeviceCache := Map()
global LastRgr06Vk := 0
global LastRgr06Sc := 0
global LastRgr06Tick := 0

global Gestures := [
    ["roller_up", "滚轮上滑", "鼠标滚轮上滚"],
    ["roller_down", "滚轮下滑", "鼠标滚轮下滚"],
    ["roller_click", "滚轮单击", "鼠标中键单击"],
    ["roller_double", "滚轮双击", "鼠标中键双击"],
    ["roller_long", "滚轮长按", "无操作"],
    ["roller_triple", "滚轮三击", "无操作"],
    ["right_click", "右侧键单击", "鼠标右键单击"],
    ["right_double", "右侧键双击", "无操作"],
    ["right_long", "右侧键长按", "无操作"],
    ["right_triple", "右侧键三击", "无操作"],
    ["left_click", "左侧键单击", "鼠标左键单击"],
    ["left_double", "左侧键双击", "鼠标左键双击"],
    ["left_long", "左侧键长按", "无操作"]
]

global ActionOptions := [
    "无操作",
    "鼠标滚轮上滚",
    "鼠标滚轮下滚",
    "鼠标左键单击",
    "鼠标左键双击",
    "鼠标右键单击",
    "鼠标中键单击",
    "鼠标中键双击",
    "启用/禁用 RGR06 触摸板",
    "回车",
    "Esc",
    "空格",
    "上一页",
    "下一页",
    "播放/暂停",
    "上一首",
    "下一首",
    "音量加",
    "音量减",
    "拍照/截图",
    "开始/停止录屏",
    "自定义按键"
]

if A_Args.Length > 0 && A_Args[1] = "--check" {
    FileAppend(AppName " " AppVersion " OK - AutoHotkey " A_AhkVersion "`n", "*")
    ExitApp
}

InitializeApp()

InitializeApp() {
    global ConfigDir, MappingActive

    DirCreate(ConfigDir)
    EnsureConfigDefaults()
    MappingActive := IniRead(ConfigPath, "General", "MappingActive", "1") = "1"
    EnsureTouchpadPrivilege()
    BuildTrayMenu()
    BuildSettingsGui()
    InitializeAhiInput()

    if A_Args.Length > 0 && A_Args[1] = "--startup" {
        SettingsGui.Hide()
    } else {
        SettingsGui.Show()
    }

    if !MappingActive {
        TrayTip(AppName, "映射已暂停")
    } else if UseAhiInput {
        TrayTip(AppName, "驱动级映射已启动")
    } else {
        TrayTip(AppName, "未找到 RGR06，映射未启动")
    }
}

EnsureTouchpadPrivilege() {
    if A_IsAdmin || !UsesTouchpadToggle() {
        return
    }
    try {
        if A_IsCompiled {
            Run('*RunAs "' A_ScriptFullPath '"' (A_Args.Length > 0 && A_Args[1] = "--startup" ? " --startup" : ""))
        } else {
            Run('*RunAs "' A_AhkPath '" "' A_ScriptFullPath '"' (A_Args.Length > 0 && A_Args[1] = "--startup" ? " --startup" : ""))
        }
        ExitApp
    } catch {
        ; Remaining mappings can still be used; touchpad toggle will prompt again when invoked.
    }
}

UsesTouchpadToggle() {
    global Gestures
    for gesture in Gestures {
        if IniRead(ConfigPath, "Mappings", gesture[1], gesture[3]) ~= "^(切换|启用/禁用) RGR06 触摸板$" {
            return true
        }
    }
    return false
}

EnsureConfigDefaults() {
    global Gestures, ConfigPath

    for gesture in Gestures {
        id := gesture[1]
        defaultAction := gesture[3]
        try {
            IniRead(ConfigPath, "Mappings", id)
        } catch {
            IniWrite(defaultAction, ConfigPath, "Mappings", id)
            IniWrite(DefaultCustom(id), ConfigPath, "Custom", id)
        }
    }
    try {
        IniRead(ConfigPath, "General", "MappingActive")
    } catch {
        IniWrite("1", ConfigPath, "General", "MappingActive")
    }
    try {
        IniRead(ConfigPath, "General", "StartWithWindows")
    } catch {
        IniWrite("0", ConfigPath, "General", "StartWithWindows")
    }
}

BuildTrayMenu() {
    A_TrayMenu.Delete()
    A_TrayMenu.Add("打开设置", ShowSettings)
    A_TrayMenu.Default := "打开设置"
    A_TrayMenu.Add("暂停/继续映射", ToggleMappingFromTray)
    A_TrayMenu.Add()
    A_TrayMenu.Add("退出", ExitApplication)
    A_IconTip := AppName
}

BuildSettingsGui() {
    global SettingsGui, StatusLabel, StartupCheckbox, ActiveCheckbox, Controls, Gestures, ActionOptions

    ui := Gui("+Resize MinSize850x590", AppName)
    ui.SetFont("s10", "Microsoft YaHei UI")
    ui.AddText("xm w940", "RGR06 指环映射启动后立即生效。为每个动作选择 Windows 功能；需要自定义时，点击“录制”再按键盘按键。")
    ui.AddText("xm w940 c006400", "当前版本使用 Raw Input 识别 RGR06 设备来源，普通键盘同名按键会尽量放行。")
    ActiveCheckbox := ui.AddCheckbox("xm y+14 Checked" (MappingActive ? 1 : 0), "启用映射")
    StartupCheckbox := ui.AddCheckbox("x+30 Checked" (IsStartupEnabled() ? 1 : 0), "随 Windows 启动")
    ui.AddText("xm y+16 w135", "指环动作")
    ui.AddText("x+10 w220", "映射功能")
    ui.AddText("x+10 w205", "已录制按键")
    ui.AddText("x+10 w150", "录制控制")

    for gesture in Gestures {
        id := gesture[1]
        label := gesture[2]
        savedAction := IniRead(ConfigPath, "Mappings", id, gesture[3])
        savedCustom := IniRead(ConfigPath, "Custom", id, "")
        ui.AddText("xm w135", label)
        ddl := ui.AddDropDownList("x+10 w220", ActionOptions)
        ddl.Choose(IndexOfAction(savedAction))
        edit := ui.AddEdit("x+10 w205 ReadOnly", DisplaySendSpec(savedCustom))
        recordButton := ui.AddButton("x+10 w70", "录制")
        clearButton := ui.AddButton("x+5 w70", "清除")
        recordButton.OnEvent("Click", BeginKeyRecording.Bind(id))
        clearButton.OnEvent("Click", ClearRecordedKey.Bind(id))
        Controls[id] := [ddl, edit, savedCustom]
    }

    saveButton := ui.AddButton("xm y+18 w120 Default", "保存并应用")
    resetButton := ui.AddButton("x+10 w120", "恢复默认")
    diagramButton := ui.AddButton("x+10 w140", "恢复鼠标默认")
    closeButton := ui.AddButton("x+10 w120", "隐藏窗口")
    StatusLabel := ui.AddText("xm y+16 w940 c006400", "程序运行中。关闭窗口后仍会保留在系统托盘。")
    ui.AddText("xm y+8 w940", "录制支持 Ctrl/Shift/Alt/Win 组合键。当前版本已放弃触摸板禁用，滚轮双击默认映射为鼠标中键双击。")

    saveButton.OnEvent("Click", SaveSettings)
    resetButton.OnEvent("Click", RestoreDefaults)
    diagramButton.OnEvent("Click", RestoreDiagramDefaults)
    closeButton.OnEvent("Click", (*) => ui.Hide())
    ui.OnEvent("Close", (*) => ui.Hide())
    SettingsGui := ui
}

RegisterRawKeyboard(hwnd) {
    global RIDEV_INPUTSINK
    rid := Buffer(8 + A_PtrSize, 0)
    NumPut("UShort", 0x01, rid, 0)
    NumPut("UShort", 0x06, rid, 2)
    NumPut("UInt", RIDEV_INPUTSINK, rid, 4)
    NumPut("Ptr", hwnd, rid, 8)
    if !DllCall("RegisterRawInputDevices", "Ptr", rid, "UInt", 1, "UInt", rid.Size) {
        TrayTip(AppName, "Raw Input 注册失败，设备级识别不可用：" A_LastError)
    }
}

OnRawInput(wParam, lParam, msg, hwnd) {
    global RID_INPUT, RawHeaderSize, LastRgr06Vk, LastRgr06Sc, LastRgr06Tick

    size := 0
    DllCall("GetRawInputData", "Ptr", lParam, "UInt", RID_INPUT, "Ptr", 0, "UInt*", &size, "UInt", RawHeaderSize)
    if size = 0 {
        return
    }
    raw := Buffer(size, 0)
    got := DllCall("GetRawInputData", "Ptr", lParam, "UInt", RID_INPUT, "Ptr", raw, "UInt*", &size, "UInt", RawHeaderSize)
    if got = 0xFFFFFFFF || NumGet(raw, 0, "UInt") != 1 {
        return
    }

    hDevice := NumGet(raw, 8, "Ptr")
    device := GetRawDeviceName(hDevice)
    if !IsRgr06RawDevice(device) {
        return
    }

    LastRgr06Sc := NumGet(raw, RawHeaderSize + 0, "UShort")
    LastRgr06Vk := NumGet(raw, RawHeaderSize + 6, "UShort")
    LastRgr06Tick := A_TickCount
}

GetRawDeviceName(hDevice) {
    global RIDI_DEVICENAME, RawDeviceCache
    key := Format("{:p}", hDevice)
    if RawDeviceCache.Has(key) {
        return RawDeviceCache[key]
    }
    chars := 0
    DllCall("GetRawInputDeviceInfoW", "Ptr", hDevice, "UInt", RIDI_DEVICENAME, "Ptr", 0, "UInt*", &chars)
    if chars = 0 {
        RawDeviceCache[key] := ""
        return ""
    }
    buf := Buffer(chars * 2, 0)
    result := DllCall("GetRawInputDeviceInfoW", "Ptr", hDevice, "UInt", RIDI_DEVICENAME, "Ptr", buf, "UInt*", &chars)
    if result = 0xFFFFFFFF {
        RawDeviceCache[key] := ""
        return ""
    }
    name := StrGet(buf, chars, "UTF-16")
    RawDeviceCache[key] := name
    return name
}

IsRgr06RawDevice(device) {
    return device ~= "i)VID&02248A|VID_02248A" && device ~= "i)PID&045B|PID_045B"
}

InitializeAhiInput() {
    global AHI, AhiTargetId, UseAhiInput
    try {
        AHI := AutoHotInterception()
        for id, dev in AHI.GetDeviceList() {
            if !dev.IsMouse && IsRgr06AhiHandle(dev.Handle) {
                AhiTargetId := id
                AHI.SubscribeKeyboard(AhiTargetId, true, AhiKeyboardEvent)
                UseAhiInput := true
                LogEvent("AHI input enabled id=" id " handle=" dev.Handle)
                return true
            }
        }
        LogEvent("AHI input unavailable: RGR06 keyboard not found")
    } catch as err {
        LogEvent("AHI input unavailable: " err.Message)
    }
    UseAhiInput := false
    return false
}

IsRgr06AhiHandle(handle) {
    return InStr(handle, "VID&02248A") || InStr(handle, "VID_02248A") || InStr(handle, "PID&045B") || InStr(handle, "PID_045B")
}

AhiKeyboardEvent(code, state) {
    global MappingActive, AhiPrefixUntil, AhiF3PulseCount, AhiF3LastPulseAt
    LogEvent("AHI event code=" code " state=" state " key=" GetKeyName("SC" Format("{:x}", code)))
    if !MappingActive || state != 1 {
        return
    }

    switch code {
        case 59: ; F1 prefix emitted before some RGR06 actions
            AhiPrefixUntil := A_TickCount + 650
        case 331, 328: ; Left / Up
            if A_TickCount <= AhiPrefixUntil {
                AhiPrefixUntil := 0
                ExecuteMapping("roller_up")
            }
        case 333, 336: ; Right / Down
            if A_TickCount <= AhiPrefixUntil {
                AhiPrefixUntil := 0
                ExecuteMapping("roller_down")
            }
        case 62: ; F4
            ExecuteMapping("roller_click")
        case 63: ; F5
            ExecuteMapping("roller_double")
        case 64: ; F6
            ExecuteMapping("roller_long")
        case 66: ; F8
            ExecuteMapping("roller_triple")
        case 284, 28: ; NumpadEnter / Enter
            ExecuteMapping("right_click")
        case 60: ; F2
            ExecuteMapping("right_long")
        case 65: ; F7
            ExecuteMapping("right_triple")
        case 61: ; F3 burst: left single / double / long-ish triple
            now := A_TickCount
            if AhiF3LastPulseAt != 0 && now - AhiF3LastPulseAt > 430 {
                ResolveAhiLeftButtonBurst()
            }
            AhiF3PulseCount += 1
            AhiF3LastPulseAt := now
            SetTimer(ResolveAhiLeftButtonBurst, -430)
    }
}

ResolveAhiLeftButtonBurst() {
    global AhiF3PulseCount, AhiF3LastPulseAt
    if AhiF3PulseCount = 1 {
        ExecuteMapping("left_click")
    } else if AhiF3PulseCount = 2 {
        ExecuteMapping("left_double")
    } else if AhiF3PulseCount > 2 {
        ExecuteMapping("left_long")
    }
    AhiF3PulseCount := 0
    AhiF3LastPulseAt := 0
}

OnAppCommand(wParam, lParam, msg, hwnd) {
    global MappingActive, LastBrowserBackTick
    if !MappingActive {
        return
    }
    command := (lParam >> 16) & 0x0FFF
    if command = 1 {
        if A_TickCount - LastBrowserBackTick > 120 {
            LastBrowserBackTick := A_TickCount
            ExecuteMapping("right_double")
        }
        return 1
    }
}

BeginKeyRecording(id, *) {
    global Controls, StatusLabel, MappingActive, RecordingGesture, RecordingPreviousActive, RecordingCaptured, RecordingMods

    CancelKeyRecording()
    RecordingGesture := id
    RecordingPreviousActive := MappingActive
    RecordingCaptured := false
    RecordingMods := Map("Ctrl", false, "Alt", false, "Shift", false, "Win", false)
    MappingActive := false
    controlsForGesture := Controls[id]
    controlsForGesture[2].Text := "等待按键..."
    StatusLabel.Text := "● 正在录制“" GestureLabel(id) "”：请按一次键盘按键或组合键。按 Esc 取消，10 秒超时。"
    RegisterRecordingHotkeys()
    SetTimer(RecordingTimeout, -10000)
}

CaptureRecordedHotkey(hotkeyName, *) {
    global RecordingGesture, RecordingCaptured, Controls, StatusLabel
    if RecordingGesture = "" {
        return
    }
    if hotkeyName = "Esc" {
        FinishKeyRecording()
        return
    }
    spec := HotkeyToSendSpec(hotkeyName)
    controlsForGesture := Controls[RecordingGesture]
    controlsForGesture[2].Text := DisplaySendSpec(spec)
    controlsForGesture[3] := spec
    controlsForGesture[1].Choose(IndexOfAction("自定义按键"))
    IniWrite("自定义按键", ConfigPath, "Mappings", RecordingGesture)
    IniWrite(spec, ConfigPath, "Custom", RecordingGesture)
    RecordingCaptured := true
    FinishKeyRecording()
}

CaptureRecordedSpec(spec) {
    global RecordingGesture, RecordingCaptured, Controls
    if RecordingGesture = "" {
        return
    }
    controlsForGesture := Controls[RecordingGesture]
    controlsForGesture[2].Text := DisplaySendSpec(spec)
    controlsForGesture[3] := spec
    controlsForGesture[1].Choose(IndexOfAction("自定义按键"))
    IniWrite("自定义按键", ConfigPath, "Mappings", RecordingGesture)
    IniWrite(spec, ConfigPath, "Custom", RecordingGesture)
    RecordingCaptured := true
    FinishKeyRecording()
}

CaptureRecordingKeyMessage(wParam, lParam, msg, hwnd) {
    global RecordingGesture, RecordingMods
    if RecordingGesture = "" {
        return
    }

    vk := wParam
    isDown := msg = 0x100 || msg = 0x104
    sc := (lParam >> 16) & 0x1FF
    keyName := GetKeyName(Format("vk{:02X}sc{:03X}", vk, sc))
    if keyName = "" {
        keyName := Format("vk{:02X}", vk)
    }

    modName := ModifierNameFromVk(vk)
    if modName != "" {
        RecordingMods[modName] := isDown
        return 0
    }

    if !isDown {
        return 0
    }

    if keyName = "Esc" {
        FinishKeyRecording()
        return 0
    }

    CaptureRecordedSpec(KeyNameToSendSpec(keyName, RecordingMods))
    return 0
}

FinishKeyRecording(*) {
    global MappingActive, RecordingPreviousActive, RecordingCaptured, RecordingGesture, StatusLabel

    if RecordingGesture = "" {
        return
    }
    UnregisterRecordingHotkeys()
    label := GestureLabel(RecordingGesture)
    MappingActive := RecordingPreviousActive
    if RecordingCaptured {
        StatusLabel.Text := "“" label "”已录制并保存为：" Controls[RecordingGesture][2].Text
    } else {
        if Controls.Has(RecordingGesture) && Controls[RecordingGesture][2].Text = "等待按键..." {
            Controls[RecordingGesture][2].Text := DisplaySendSpec(Controls[RecordingGesture][3])
        }
        StatusLabel.Text := "“" label "”录制超时，未修改映射。"
    }
    RecordingGesture := ""
}

CancelKeyRecording() {
    global RecordingGesture, MappingActive, RecordingPreviousActive
    if RecordingGesture != "" {
        RecordingGesture := ""
        MappingActive := RecordingPreviousActive
        UnregisterRecordingHotkeys()
    }
}

RecordingTimeout() {
    FinishKeyRecording()
}

RegisterRecordingHotkeys() {
    global RecordingHotkeys
    RecordingHotkeys := []
    OnMessage(0x100, CaptureRecordingKeyMessage)
    OnMessage(0x101, CaptureRecordingKeyMessage)
    OnMessage(0x104, CaptureRecordingKeyMessage)
    OnMessage(0x105, CaptureRecordingKeyMessage)
}

UnregisterRecordingHotkeys() {
    global RecordingHotkeys
    OnMessage(0x100, CaptureRecordingKeyMessage, 0)
    OnMessage(0x101, CaptureRecordingKeyMessage, 0)
    OnMessage(0x104, CaptureRecordingKeyMessage, 0)
    OnMessage(0x105, CaptureRecordingKeyMessage, 0)
    RecordingHotkeys := []
}

RecordingKeyList() {
    keys := []
    Loop 26 {
        keys.Push(Chr(Ord("A") + A_Index - 1))
    }
    Loop 10 {
        keys.Push(String(A_Index - 1))
    }
    for key in ["Enter","Tab","Space","Backspace","Delete","Insert","Home","End","PgUp","PgDn","Up","Down","Left","Right","Esc","PrintScreen"] {
        keys.Push(key)
    }
    Loop 12 {
        keys.Push("F" A_Index)
    }
    return keys
}

ClearRecordedKey(id, *) {
    global Controls, StatusLabel
    controlsForGesture := Controls[id]
    controlsForGesture[2].Text := ""
    controlsForGesture[3] := ""
    if controlsForGesture[1].Text = "自定义按键" {
        controlsForGesture[1].Choose(IndexOfAction("无操作"))
    }
    StatusLabel.Text := "已清除“" GestureLabel(id) "”的录制按键；点击“保存并应用”确认。"
}

GestureLabel(id) {
    global Gestures
    for gesture in Gestures {
        if gesture[1] = id {
            return gesture[2]
        }
    }
    return id
}

IsModifierKey(keyName) {
    return keyName ~= "i)^(LControl|RControl|Control|LShift|RShift|Shift|LAlt|RAlt|Alt|LWin|RWin)$"
}

HotkeyToSendSpec(hotkeyName) {
    text := RegExReplace(hotkeyName, "^[*~$]+")
    text := RegExReplace(text, "[<>]")
    prefix := ""
    while text != "" && InStr("^!+#", SubStr(text, 1, 1)) {
        prefix .= SubStr(text, 1, 1)
        text := SubStr(text, 2)
    }
    if text = "Return" {
        text := "Enter"
    }
    return prefix "{" text "}"
}

KeyNameToSendSpec(keyName, mods := "") {
    prefix := ""
    if mods = "" {
        mods := Map("Ctrl", false, "Alt", false, "Shift", false, "Win", false)
    }
    if mods["Ctrl"] && !(keyName ~= "i)Control" || keyName ~= "i)Ctrl") {
        prefix .= "^"
    }
    if mods["Alt"] && !(keyName ~= "i)Alt") {
        prefix .= "!"
    }
    if mods["Shift"] && !(keyName ~= "i)Shift") {
        prefix .= "+"
    }
    if mods["Win"] && !(keyName ~= "i)Win") {
        prefix .= "#"
    }
    return prefix "{" keyName "}"
}

ModifierNameFromVk(vk) {
    switch vk {
        case 0x11, 0xA2, 0xA3:
            return "Ctrl"
        case 0x12, 0xA4, 0xA5:
            return "Alt"
        case 0x10, 0xA0, 0xA1:
            return "Shift"
        case 0x5B, 0x5C:
            return "Win"
        default:
            return ""
    }
}

DisplaySendSpec(spec) {
    if spec = "" {
        return ""
    }
    text := spec
    display := ""
    while text != "" && InStr("^!+#", SubStr(text, 1, 1)) {
        ch := SubStr(text, 1, 1)
        switch ch {
            case "^":
                display .= "Ctrl+"
            case "!":
                display .= "Alt+"
            case "+":
                display .= "Shift+"
            case "#":
                display .= "Win+"
        }
        text := SubStr(text, 2)
    }
    text := StrReplace(text, "{", "")
    text := StrReplace(text, "}", "")
    return display text
}

IndexOfAction(action) {
    global ActionOptions
    for index, option in ActionOptions {
        if option = action {
            return index
        }
    }
    return 1
}

SaveSettings(*) {
    global Gestures, Controls, MappingActive, ActiveCheckbox, StartupCheckbox, StatusLabel

    for gesture in Gestures {
        id := gesture[1]
        controlsForGesture := Controls[id]
        IniWrite(controlsForGesture[1].Text, ConfigPath, "Mappings", id)
        IniWrite(controlsForGesture[3], ConfigPath, "Custom", id)
    }
    MappingActive := ActiveCheckbox.Value = 1
    IniWrite(MappingActive ? "1" : "0", ConfigPath, "General", "MappingActive")
    SetStartup(StartupCheckbox.Value = 1)
    StatusLabel.Text := "已保存。映射" (MappingActive ? "已启用" : "已暂停") "，设置立即生效。"
    TrayTip(AppName, StatusLabel.Text)
}

RestoreDefaults(*) {
    global Gestures, Controls, ActiveCheckbox
    for gesture in Gestures {
        controlsForGesture := Controls[gesture[1]]
        controlsForGesture[1].Choose(IndexOfAction(gesture[3]))
        controlsForGesture[2].Text := ""
        controlsForGesture[3] := ""
    }
    ActiveCheckbox.Value := 1
    SaveSettings()
}

RestoreDiagramDefaults(*) {
    global Gestures, Controls, ActiveCheckbox, StatusLabel
    for gesture in Gestures {
        id := gesture[1]
        controlsForGesture := Controls[id]
        controlsForGesture[1].Choose(IndexOfAction(gesture[3]))
        controlsForGesture[2].Text := DisplaySendSpec(DefaultCustom(id))
        controlsForGesture[3] := DefaultCustom(id)
    }
    ActiveCheckbox.Value := 1
    StatusLabel.Text := "已载入鼠标默认映射；点击“保存并应用”确认。"
}

DefaultCustom(id) {
    return ""
}

IsStartupEnabled() {
    value := ""
    try value := RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Run", AppName)
    return value != ""
}

SetStartup(enabled) {
    command := '"' A_ScriptFullPath '" --startup'
    if A_IsCompiled {
        command := '"' A_ScriptFullPath '" --startup'
    } else {
        command := '"' A_AhkPath '" "' A_ScriptFullPath '" --startup'
    }
    if enabled {
        RegWrite(command, "REG_SZ", "HKCU\Software\Microsoft\Windows\CurrentVersion\Run", AppName)
    } else {
        try RegDelete("HKCU\Software\Microsoft\Windows\CurrentVersion\Run", AppName)
    }
    IniWrite(enabled ? "1" : "0", ConfigPath, "General", "StartWithWindows")
}

ShowSettings(*) {
    global SettingsGui
    SettingsGui.Show()
    WinActivate(SettingsGui.Hwnd)
}

ToggleMappingFromTray(*) {
    global MappingActive, ActiveCheckbox, StatusLabel
    MappingActive := !MappingActive
    ActiveCheckbox.Value := MappingActive ? 1 : 0
    IniWrite(MappingActive ? "1" : "0", ConfigPath, "General", "MappingActive")
    StatusLabel.Text := MappingActive ? "映射已启用。" : "映射已暂停。"
    TrayTip(AppName, StatusLabel.Text)
}

ExitApplication(*) {
    CancelKeyRecording()
    ExitApp
}

GetMapping(id) {
    return IniRead(ConfigPath, "Mappings", id, "无操作")
}

ExecuteMapping(id) {
    action := GetMapping(id)
    LogEvent("ExecuteMapping id=" id " action=" action)
    switch action {
        case "无操作":
            return
        case "鼠标滚轮上滚":
            Send "{WheelUp}"
        case "鼠标滚轮下滚":
            Send "{WheelDown}"
        case "鼠标左键单击":
            Send "{LButton}"
        case "鼠标左键双击":
            Send "{LButton 2}"
        case "鼠标右键单击":
            Send "{RButton}"
        case "鼠标中键单击":
            Send "{MButton}"
        case "鼠标中键双击":
            Send "{MButton 2}"
        case "切换 RGR06 触摸板", "启用/禁用 RGR06 触摸板":
            ToggleRgr06Touchpad()
        case "回车":
            Send "{Enter}"
        case "Esc":
            Send "{Esc}"
        case "空格":
            Send "{Space}"
        case "上一页":
            Send "{PgUp}"
        case "下一页":
            Send "{PgDn}"
        case "播放/暂停":
            Send "{Media_Play_Pause}"
        case "上一首":
            Send "{Media_Prev}"
        case "下一首":
            Send "{Media_Next}"
        case "音量加":
            Send "{Volume_Up}"
        case "音量减":
            Send "{Volume_Down}"
        case "拍照/截图":
            Send "{PrintScreen}"
        case "开始/停止录屏":
            Send "#!r"
        case "自定义按键":
            custom := IniRead(ConfigPath, "Custom", id, "")
            LogEvent("Custom id=" id " value=" custom)
            if custom != "" {
                try Send(custom)
            }
    }
}

LogEvent(message) {
    global ConfigDir
    try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") "." Format("{:03}", Mod(A_MSec, 1000)) " " message "`n", ConfigDir "\events.log", "UTF-8")
}

ToggleRgr06Touchpad() {
    global TouchpadScript, TouchpadStatusPath
    if !FileExist(TouchpadScript) {
        TrayTip(AppName, "未找到触摸板切换脚本。")
        return
    }
    try {
        if FileExist(TouchpadStatusPath) {
            FileDelete(TouchpadStatusPath)
        }
        args := '-NoProfile -ExecutionPolicy Bypass -File "' TouchpadScript '" -StatusPath "' TouchpadStatusPath '"'
        if A_IsAdmin {
            RunWait('powershell.exe ' args, , "Hide")
        } else {
            RunWait('*RunAs powershell.exe ' args, , "Hide")
        }
        state := FileExist(TouchpadStatusPath) ? Trim(FileRead(TouchpadStatusPath)) : "ERROR"
        if InStr(state, "DISABLED:") = 1 {
            TrayTip(AppName, "RGR06 触摸板已禁用。")
        } else if InStr(state, "ENABLED:") = 1 {
            TrayTip(AppName, "RGR06 触摸板已启用。")
        } else {
            TrayTip(AppName, "触摸板切换失败：" state)
        }
    } catch {
        TrayTip(AppName, "已取消触摸板切换。")
    }
}

#HotIf MappingActive && UseCompatHotkeys

; The ring produces F1 as a prefix before most recognized actions.
$*F1:: {
    global PrefixUntil
    PrefixUntil := A_TickCount + 650
}
$*F1 up::Return

#HotIf MappingActive && UseCompatHotkeys

$*Left:: {
    global PrefixUntil, SuppressUpUntil
    if A_TickCount <= PrefixUntil {
        PrefixUntil := 0
        SuppressUpUntil := A_TickCount + 350
        ExecuteMapping("roller_up")
        return
    }
    Send "{Blind}{Left}"
}

#HotIf MappingActive && UseCompatHotkeys
$*Up:: {
    global SuppressUpUntil
    if A_TickCount <= SuppressUpUntil {
        SuppressUpUntil := 0
        return
    }
    Send "{Blind}{Up}"
}

#HotIf MappingActive && UseCompatHotkeys
$*Right:: {
    global PrefixUntil, SuppressDownUntil
    if A_TickCount <= PrefixUntil {
        PrefixUntil := 0
        SuppressDownUntil := A_TickCount + 350
        ExecuteMapping("roller_down")
        return
    }
    Send "{Blind}{Right}"
}

#HotIf MappingActive && UseCompatHotkeys
$*Down:: {
    global SuppressDownUntil
    if A_TickCount <= SuppressDownUntil {
        SuppressDownUntil := 0
        return
    }
    Send "{Blind}{Down}"
}

#HotIf MappingActive && UseCompatHotkeys
$*F4::ExecuteMapping("roller_click")

#HotIf MappingActive && UseCompatHotkeys
$*F5::ExecuteMapping("roller_double")

#HotIf MappingActive && UseCompatHotkeys
$*F6::ExecuteMapping("roller_long")

#HotIf MappingActive && UseCompatHotkeys
$*F8::ExecuteMapping("roller_triple")

#HotIf MappingActive && UseCompatHotkeys
$*Enter::ExecuteMapping("right_click")

#HotIf MappingActive && UseCompatHotkeys
$*Browser_Back:: {
    global LastBrowserBackTick
    LastBrowserBackTick := A_TickCount
    ExecuteMapping("right_double")
}

#HotIf MappingActive && UseCompatHotkeys
$*F7::ExecuteMapping("right_triple")

#HotIf MappingActive && UseCompatHotkeys
$*F2:: {
    global F2Triggered
    if !F2Triggered {
        F2Triggered := true
        ExecuteMapping("right_long")
    }
    SetTimer(ResetF2Burst, -220)
}
$*F2 up::SetTimer(ResetF2Burst, -220)

#HotIf MappingActive && UseCompatHotkeys
$*F3:: {
    global F3PulseCount, F3LastPulseAt
    now := A_TickCount
    if F3LastPulseAt != 0 && now - F3LastPulseAt > 430 {
        ResolveLeftButtonBurst()
    }
    F3PulseCount += 1
    F3LastPulseAt := now
    SetTimer(ResolveLeftButtonBurst, -430)
}
$*F3 up::Return

#HotIf

IsRecentRgr06Vk(vk) {
    global LastRgr06Vk, LastRgr06Tick
    return LastRgr06Vk = vk && A_TickCount - LastRgr06Tick < 180
}

ResetF2Burst() {
    global F2Triggered
    F2Triggered := false
}

ResolveLeftButtonBurst() {
    global F3PulseCount, F3LastPulseAt
    if F3PulseCount = 1 {
        ExecuteMapping("left_click")
    } else if F3PulseCount = 2 {
        ExecuteMapping("left_double")
    } else if F3PulseCount > 2 {
        ExecuteMapping("left_long")
    }
    F3PulseCount := 0
    F3LastPulseAt := 0
}

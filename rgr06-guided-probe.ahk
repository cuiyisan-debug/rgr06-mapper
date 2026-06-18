#Requires AutoHotkey v2.0
#SingleInstance Force

Persistent
InstallKeybdHook
KeyHistory 200

global ProbeTitle := "RGR06 Guided Mapping Probe"
global LogPath := A_ScriptDir "\rgr06-guided-events-" FormatTime(, "yyyyMMdd-HHmmss") ".csv"
global CurrentTest := "(未选择)"
global LastSignature := ""
global LastTick := 0
global EventCount := 0
global Output := ""
global StatusText := ""
global TestSelector := ""

RegisterCaptureHotkeys()

if A_Args.Length > 0 && A_Args[1] = "--check" {
    FileAppend("RGR06 Guided Probe OK - AutoHotkey " A_AhkVersion "`n", "*")
    ExitApp
}

InitializeLog()
BuildUi()

RegisterCaptureHotkeys() {
    Loop 511 {
        key := Format("sc{:03X}", A_Index)
        TryRegister("~*" key, LogInput)
        TryRegister("~*" key " up", LogInput)
    }
    for key in [
        "Volume_Mute", "Volume_Down", "Volume_Up",
        "Media_Next", "Media_Prev", "Media_Stop", "Media_Play_Pause",
        "Browser_Back", "Browser_Forward", "Browser_Home",
        "Launch_Media", "Launch_App1", "Launch_App2"
    ] {
        if GetKeySC(key) = 0 {
            TryRegister("~*" key, LogInput)
            TryRegister("~*" key " up", LogInput)
        }
    }
}

TryRegister(hotkeyName, callback) {
    try {
        Hotkey(hotkeyName, callback, "On")
    }
}

InitializeLog() {
    FileAppend("time,physical_action,event,key,vk,sc,hotkey`n", LogPath, "UTF-8")
}

BuildUi() {
    global Output, StatusText, TestSelector

    tests := [
        "滚轮 - 上滑（向左/向上选择）",
        "滚轮 - 下滑（向右/向下选择）",
        "滚轮 - 长按1秒（息屏/亮屏）",
        "滚轮 - 单击（播放/暂停）",
        "滚轮 - 双击（下一首）",
        "滚轮 - 三击（上一首）",
        "右侧键 - 单击（确认）",
        "右侧键 - 双击（返回）",
        "右侧键 - 长按（唤醒AI助手）",
        "右侧键 - 三击（AI快捷指令）",
        "左侧键 - 单击（拍照）",
        "左侧键 - 长按1秒（开始/停止录像）",
        "触摸板 - 触摸移动（移动光标）",
        "触摸板 - 单击（光标确认）"
    ]

    ui := Gui("+Resize", ProbeTitle)
    ui.SetFont("s10", "Microsoft YaHei UI")
    ui.AddText("w1050", "按说明图逐项测试：选择一项 -> 点击“开始记录该动作” -> 只在指环上重复动作 3 次。")
    ui.AddText("w1050", "提示：长按保持约 1 秒；双击/三击尽量连续。测试期间不要使用电脑键盘。")
    TestSelector := ui.AddDropDownList("xm w430 Choose1", tests)
    btnStart := ui.AddButton("x+10 w170 Default", "开始记录该动作")
    btnStop := ui.AddButton("x+10 w130", "暂停标记")
    StatusText := ui.AddText("xm w1050 c006400", "尚未开始动作标记。日志：" LogPath)
    Output := ui.AddListView("xm w1050 r22 Grid -Multi", ["时间", "物理动作", "事件", "键名", "VK", "SC"])
    Output.ModifyCol(1, 115)
    Output.ModifyCol(2, 315)
    Output.ModifyCol(3, 60)
    Output.ModifyCol(4, 160)
    Output.ModifyCol(5, 70)
    Output.ModifyCol(6, 70)
    btnClear := ui.AddButton("xm w120", "清空界面")
    btnHistory := ui.AddButton("x+10 w150", "打开 KeyHistory")
    btnFolder := ui.AddButton("x+10 w150", "打开日志目录")
    btnExit := ui.AddButton("x+10 w120", "退出")

    btnStart.OnEvent("Click", BeginSelectedTest)
    btnStop.OnEvent("Click", PauseTagging)
    btnClear.OnEvent("Click", ClearView)
    btnHistory.OnEvent("Click", ShowHistory)
    btnFolder.OnEvent("Click", OpenLogFolder)
    btnExit.OnEvent("Click", ExitProbe)
    ui.OnEvent("Close", ExitProbe)
    ui.OnEvent("Size", ResizeUi)
    ui.Show("w1090 h650")

    Hotkey("^!F8", ShowHistory)
    Hotkey("^!F12", ExitProbe)
}

BeginSelectedTest(*) {
    global CurrentTest, TestSelector, StatusText
    CurrentTest := TestSelector.Text
    WriteMarker("START", CurrentTest)
    StatusText.Text := "当前动作：" CurrentTest "。请在指环上重复执行 3 次，然后选择下一项。"
}

PauseTagging(*) {
    global CurrentTest, StatusText
    WriteMarker("STOP", CurrentTest)
    CurrentTest := "(暂停)"
    StatusText.Text := "已暂停标记。请选择下一个物理动作后继续。"
}

WriteMarker(marker, label) {
    when := Timestamp()
    FileAppend(Csv(when) "," Csv(label) "," Csv(marker) ",,,," "`n", LogPath, "UTF-8")
}

LogInput(thisHotkey) {
    global Output, StatusText, CurrentTest, LastSignature, LastTick, EventCount

    stripped := RegExReplace(thisHotkey, "^[~*$<>#!+^]*")
    event := InStr(stripped, " up") ? "Up" : "Down"
    keyToken := StrReplace(stripped, " up")
    keyName := GetKeyName(keyToken)
    if keyName = "" {
        keyName := keyToken
    }
    vk := GetKeyVK(keyToken)
    sc := GetKeySC(keyToken)
    signature := event "|" vk "|" sc
    if signature = LastSignature && A_TickCount - LastTick < 12 {
        return
    }
    LastSignature := signature
    LastTick := A_TickCount

    when := Timestamp()
    vkText := vk ? Format("0x{:02X}", vk) : "-"
    scText := sc ? Format("0x{:03X}", sc) : "-"
    Output.Add(, when, CurrentTest, event, keyName, vkText, scText)
    Output.Modify(Output.GetCount(), "Vis")
    EventCount += 1
    StatusText.Text := "当前动作：" CurrentTest "；最近输入：" event " " keyName "；共 " EventCount " 条事件。"
    FileAppend(
        Csv(when) "," Csv(CurrentTest) "," Csv(event) "," Csv(keyName) "," Csv(vkText) "," Csv(scText) "," Csv(thisHotkey) "`n",
        LogPath,
        "UTF-8"
    )
}

Timestamp() {
    return FormatTime(, "HH:mm:ss") "." Format("{:03}", A_MSec)
}

Csv(value) {
    return '"' StrReplace(value, '"', '""') '"'
}

ClearView(*) {
    global Output, StatusText
    Output.Delete()
    StatusText.Text := "界面已清空；CSV 日志仍保留全部记录。"
}

ShowHistory(*) {
    KeyHistory
}

OpenLogFolder(*) {
    Run(A_ScriptDir)
}

ResizeUi(guiObj, minMax, width, height) {
    global Output
    if minMax = -1 {
        return
    }
    Output.Move(, , Max(600, width - 40), Max(180, height - 175))
}

ExitProbe(*) {
    ExitApp
}

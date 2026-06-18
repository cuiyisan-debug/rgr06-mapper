#Requires AutoHotkey v2.0
#SingleInstance Force

Persistent
InstallKeybdHook
KeyHistory 200

global ProbeTitle := "RGR06 Input Probe"
global LogPath := A_ScriptDir "\rgr06-events-" FormatTime(, "yyyyMMdd-HHmmss") ".csv"
global EventList := []
global LastSignature := ""
global LastTick := 0
global Output := ""
global StatusText := ""

RegisterCaptureHotkeys()

if A_Args.Length > 0 && A_Args[1] = "--check" {
    FileAppend("RGR06 Input Probe OK - AutoHotkey " A_AhkVersion "`n", "*")
    ExitApp
}

BuildUi()
InitializeLog()

RegisterCaptureHotkeys() {
    Loop 511 {
        key := Format("sc{:03X}", A_Index)
        TryRegister("~*" key, LogInput)
        TryRegister("~*" key " up", LogInput)
    }

    ; These keys are commonly produced by Bluetooth media remotes.
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

BuildUi() {
    global Output, StatusText

    ui := Gui("+Resize", ProbeTitle)
    ui.SetFont("s10", "Microsoft YaHei UI")
    ui.AddText("w910", "请只操作 RGR06：依次测试单击、双击、长按、上下左右滑动。脚本不会拦截原有按键行为。")
    ui.AddText("w910", "说明：AutoHotkey 能看到 Windows 转换出的键盘/媒体事件，但当前阶段不能区分同键值来自指环还是普通键盘。")
    StatusText := ui.AddText("w910 c006400", "等待输入。日志将自动保存到：" LogPath)
    Output := ui.AddListView("w910 r22 Grid -Multi", ["时间", "动作", "键名", "VK", "SC", "AutoHotkey 热键"])
    Output.ModifyCol(1, 115)
    Output.ModifyCol(2, 60)
    Output.ModifyCol(3, 200)
    Output.ModifyCol(4, 80)
    Output.ModifyCol(5, 80)
    Output.ModifyCol(6, 260)

    btnClear := ui.AddButton("xm w120", "清空列表")
    btnHistory := ui.AddButton("x+10 w160", "打开 KeyHistory")
    btnFolder := ui.AddButton("x+10 w160", "打开日志目录")
    btnExit := ui.AddButton("x+10 w120", "退出")
    ui.AddText("xm w910", "快捷键：Ctrl+Alt+F8 打开 KeyHistory；Ctrl+Alt+F9 清空；Ctrl+Alt+F12 退出。")

    btnClear.OnEvent("Click", ClearEvents)
    btnHistory.OnEvent("Click", ShowHistory)
    btnFolder.OnEvent("Click", OpenLogFolder)
    btnExit.OnEvent("Click", ExitProbe)
    ui.OnEvent("Close", ExitProbe)
    ui.OnEvent("Size", ResizeUi)
    ui.Show("w950 h610")

    Hotkey("^!F8", ShowHistory)
    Hotkey("^!F9", ClearEvents)
    Hotkey("^!F12", ExitProbe)
}

InitializeLog() {
    FileAppend("time,action,key,vk,sc,hotkey`n", LogPath, "UTF-8")
}

LogInput(thisHotkey) {
    global Output, StatusText, EventList, LastSignature, LastTick

    stripped := RegExReplace(thisHotkey, "^[~*$<>#!+^]*")
    action := InStr(stripped, " up") ? "Up" : "Down"
    keyToken := StrReplace(stripped, " up")
    keyName := GetKeyName(keyToken)
    if keyName = "" {
        keyName := keyToken
    }
    vk := GetKeyVK(keyToken)
    sc := GetKeySC(keyToken)
    signature := action "|" vk "|" sc

    ; Named and scan-code hotkeys may represent the same physical report.
    if signature = LastSignature && A_TickCount - LastTick < 12 {
        return
    }
    LastSignature := signature
    LastTick := A_TickCount

    when := FormatTime(, "HH:mm:ss") "." Format("{:03}", A_MSec)
    vkText := vk ? Format("0x{:02X}", vk) : "-"
    scText := sc ? Format("0x{:03X}", sc) : "-"
    values := [when, action, keyName, vkText, scText, thisHotkey]
    EventList.Push(values)
    Output.Add(, values*)
    Output.Modify(Output.GetCount(), "Vis")
    StatusText.Text := "最近输入：" action " " keyName "  " vkText " / " scText "    共记录 " EventList.Length " 条"
    FileAppend(
        Csv(when) "," Csv(action) "," Csv(keyName) "," Csv(vkText) "," Csv(scText) "," Csv(thisHotkey) "`n",
        LogPath,
        "UTF-8"
    )
}

Csv(value) {
    return '"' StrReplace(value, '"', '""') '"'
}

ClearEvents(*) {
    global Output, StatusText, EventList
    Output.Delete()
    EventList := []
    StatusText.Text := "列表已清空；日志文件仍保留完整记录。"
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
    Output.Move(, , Max(500, width - 40), Max(180, height - 165))
}

ExitProbe(*) {
    ExitApp
}

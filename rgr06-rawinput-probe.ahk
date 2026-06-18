#Requires AutoHotkey v2.0
#SingleInstance Force

; Raw Input probe for distinguishing RGR06 keyboard reports from the laptop keyboard.

global WM_INPUT := 0x00FF
global RID_INPUT := 0x10000003
global RIDI_DEVICENAME := 0x20000007
global RIDEV_INPUTSINK := 0x00000100
global HeaderSize := 8 + A_PtrSize * 2
global DeviceCache := Map()
global LogPath := A_ScriptDir "\rgr06-rawinput-" FormatTime(, "yyyyMMdd-HHmmss") ".csv"
global EventList := ""
global StatusText := ""

if A_Args.Length > 0 && A_Args[1] = "--check" {
    FileAppend("Raw Input probe OK`n", "*")
    ExitApp
}

Initialize()

Initialize() {
    global EventList, StatusText, LogPath

    ui := Gui("+Resize", "RGR06 Raw Input Probe")
    ui.SetFont("s10", "Microsoft YaHei UI")
    ui.AddText("w1150", "这个窗口用于确认每个按键来自哪个物理 HID 设备。请分别按电脑键盘 Enter、RGR06 右侧单击、左侧单击、滚轮动作。")
    StatusText := ui.AddText("w1150 c006400", "等待 Raw Input。日志：" LogPath)
    EventList := ui.AddListView("w1150 r24 Grid -Multi", ["时间", "VK", "SC", "消息", "RGR06?", "设备路径"])
    EventList.ModifyCol(1, 110)
    EventList.ModifyCol(2, 70)
    EventList.ModifyCol(3, 70)
    EventList.ModifyCol(4, 90)
    EventList.ModifyCol(5, 70)
    EventList.ModifyCol(6, 700)
    btnClear := ui.AddButton("xm w120", "清空界面")
    btnFolder := ui.AddButton("x+10 w150", "打开日志目录")
    btnExit := ui.AddButton("x+10 w120", "退出")
    btnClear.OnEvent("Click", (*) => EventList.Delete())
    btnFolder.OnEvent("Click", (*) => Run(A_ScriptDir))
    btnExit.OnEvent("Click", (*) => ExitApp())
    ui.OnEvent("Close", (*) => ExitApp())
    ui.Show("w1190 h670")

    FileAppend("time,vk,sc,message,is_rgr06,device`n", LogPath, "UTF-8")
    RegisterRawKeyboard(ui.Hwnd)
    OnMessage(WM_INPUT, OnRawInput)
}

RegisterRawKeyboard(hwnd) {
    global RIDEV_INPUTSINK
    rid := Buffer(8 + A_PtrSize, 0)
    NumPut("UShort", 0x01, rid, 0)      ; Generic Desktop
    NumPut("UShort", 0x06, rid, 2)      ; Keyboard
    NumPut("UInt", RIDEV_INPUTSINK, rid, 4)
    NumPut("Ptr", hwnd, rid, 8)
    ok := DllCall("RegisterRawInputDevices", "Ptr", rid, "UInt", 1, "UInt", rid.Size)
    if !ok {
        MsgBox("RegisterRawInputDevices failed: " A_LastError, "RGR06 Raw Input Probe")
        ExitApp
    }
}

OnRawInput(wParam, lParam, msg, hwnd) {
    global RID_INPUT, HeaderSize, EventList, StatusText, LogPath

    size := 0
    DllCall("GetRawInputData", "Ptr", lParam, "UInt", RID_INPUT, "Ptr", 0, "UInt*", &size, "UInt", HeaderSize)
    if size = 0 {
        return
    }
    raw := Buffer(size, 0)
    got := DllCall("GetRawInputData", "Ptr", lParam, "UInt", RID_INPUT, "Ptr", raw, "UInt*", &size, "UInt", HeaderSize)
    if got = 0xFFFFFFFF {
        return
    }

    type := NumGet(raw, 0, "UInt")
    if type != 1 { ; RIM_TYPEKEYBOARD
        return
    }

    hDevice := NumGet(raw, 8, "Ptr")
    device := GetDeviceName(hDevice)
    offset := HeaderSize
    sc := NumGet(raw, offset + 0, "UShort")
    vk := NumGet(raw, offset + 6, "UShort")
    message := NumGet(raw, offset + 8, "UInt")
    isRgr06 := IsRgr06Device(device) ? "YES" : "NO"
    when := FormatTime(, "HH:mm:ss") "." Format("{:03}", A_MSec)
    vkText := Format("0x{:02X}", vk)
    scText := Format("0x{:03X}", sc)
    msgText := Format("0x{:04X}", message)

    EventList.Add(, when, vkText, scText, msgText, isRgr06, device)
    EventList.Modify(EventList.GetCount(), "Vis")
    StatusText.Text := "最近：" vkText " / " scText " from " (isRgr06 = "YES" ? "RGR06" : "非 RGR06")
    FileAppend(Csv(when) "," Csv(vkText) "," Csv(scText) "," Csv(msgText) "," Csv(isRgr06) "," Csv(device) "`n", LogPath, "UTF-8")
}

GetDeviceName(hDevice) {
    global RIDI_DEVICENAME, DeviceCache
    key := Format("{:p}", hDevice)
    if DeviceCache.Has(key) {
        return DeviceCache[key]
    }

    chars := 0
    DllCall("GetRawInputDeviceInfoW", "Ptr", hDevice, "UInt", RIDI_DEVICENAME, "Ptr", 0, "UInt*", &chars)
    if chars = 0 {
        DeviceCache[key] := ""
        return ""
    }
    buf := Buffer(chars * 2, 0)
    result := DllCall("GetRawInputDeviceInfoW", "Ptr", hDevice, "UInt", RIDI_DEVICENAME, "Ptr", buf, "UInt*", &chars)
    if result = 0xFFFFFFFF {
        DeviceCache[key] := ""
        return ""
    }
    name := StrGet(buf, chars, "UTF-16")
    DeviceCache[key] := name
    return name
}

IsRgr06Device(device) {
    return device ~= "i)VID_02248A|VID&02248A|PID_045B|PID&045B|D10977BC366F|D10777BC366F"
}

Csv(value) {
    return '"' StrReplace(value, '"', '""') '"'
}

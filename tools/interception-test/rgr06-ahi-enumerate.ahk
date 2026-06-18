#Requires AutoHotkey v2.0
#SingleInstance Force
#include AutoHotInterception\AHK v2\Lib\AutoHotInterception.ahk

logPath := A_ScriptDir "\rgr06-ahi-devices.log"
FileDelete(logPath)
Log("RGR06 AutoHotInterception device enumeration")
Log("Time: " FormatTime(, "yyyy-MM-dd HH:mm:ss"))
Log("")

try {
    AHI := AutoHotInterception()
    devices := AHI.GetDeviceList()
    found := false

    for id, dev in devices {
        kind := dev.IsMouse ? "Mouse" : "Keyboard"
        vidHex := Format("0x{:04X}", dev.VID)
        pidHex := Format("0x{:04X}", dev.PID)
        handle := dev.Handle
        isRgr06 := InStr(handle, "VID&02248A") || InStr(handle, "VID_02248A") || InStr(handle, "PID&045B") || InStr(handle, "PID_045B")
        if isRgr06 {
            found := true
        }
        Log(Format("ID={:02} Type={} VID={} PID={} RGR06={}", id, kind, vidHex, pidHex, isRgr06 ? "YES" : "NO"))
        Log("Handle=" handle)
        Log("")
    }

    if found {
        MsgBox("AHI 已能看到 RGR06。结果已写入：`n" logPath, "RGR06 AHI 测试")
    } else {
        MsgBox("AHI 已运行，但没有在设备列表里找到 RGR06。结果已写入：`n" logPath, "RGR06 AHI 测试")
    }
} catch as err {
    Log("ERROR: " err.Message)
    Log("Extra: " err.Extra)
    MsgBox("AHI 枚举失败，通常表示 Interception 驱动还没有安装或 DLL 未加载。`n`n" err.Message "`n`n日志：`n" logPath, "RGR06 AHI 测试")
}

Run("notepad.exe " Quote(logPath))

Log(text) {
    global logPath
    FileAppend(text "`n", logPath, "UTF-8")
}

Quote(path) {
    return '"' path '"'
}

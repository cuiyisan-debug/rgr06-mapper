#Requires AutoHotkey v2.0
#SingleInstance Force

; RGR06 mouse mapping. Enable or disable mappings with Ctrl+Alt+R.
; This AutoHotkey version acts on key values. While mappings are enabled,
; matching keys on a normal keyboard can also be intercepted.

global MappingEnabled := false
global PrefixUntil := 0
global IgnoreUpUntil := 0
global IgnoreDownUntil := 0
global LeftButtonPulseCount := 0
global TouchpadToggleScript := A_ScriptDir "\toggle-rgr06-touchpad.ps1"
global TouchpadStatusFile := A_ScriptDir "\rgr06-touchpad-status.txt"

if A_Args.Length > 0 && A_Args[1] = "--check" {
    FileAppend("RGR06 Mapper OK - AutoHotkey " A_AhkVersion "`n", "*")
    ExitApp
}

if !A_IsAdmin {
    try {
        Run('*RunAs "' A_AhkPath '" "' A_ScriptFullPath '"')
    } catch {
        MsgBox("滚轮双击切换 RGR06 触摸板需要管理员权限。映射脚本未启动。", "RGR06 Mapper")
    }
    ExitApp
}

^!r:: {
    global MappingEnabled
    MappingEnabled := !MappingEnabled
    TrayTip("RGR06 Mapper", MappingEnabled ? "映射已开启" : "映射已关闭")
}

#HotIf MappingEnabled

; Common prefix reported by the ring. It must not open Windows Help.
$F1:: {
    global PrefixUntil
    PrefixUntil := A_TickCount + 650
}
$F1 up::Return

; Requested mapping: roller swipe -> mouse wheel.
$Left:: {
    global PrefixUntil, IgnoreUpUntil
    if A_TickCount <= PrefixUntil {
        PrefixUntil := 0
        IgnoreUpUntil := A_TickCount + 350
        Send "{WheelUp}"
        return
    }
    Send "{Blind}{Left}"
}
$Up:: {
    global IgnoreUpUntil
    if A_TickCount <= IgnoreUpUntil {
        IgnoreUpUntil := 0
        return
    }
    Send "{Blind}{Up}"
}
$Right:: {
    global PrefixUntil, IgnoreDownUntil
    if A_TickCount <= PrefixUntil {
        PrefixUntil := 0
        IgnoreDownUntil := A_TickCount + 350
        Send "{WheelDown}"
        return
    }
    Send "{Blind}{Right}"
}
$Down:: {
    global IgnoreDownUntil
    if A_TickCount <= IgnoreDownUntil {
        IgnoreDownUntil := 0
        return
    }
    Send "{Blind}{Down}"
}

; Requested mapping: roller single click -> mouse middle click.
$F4::Send "{MButton}"

; Requested mapping: roller double click -> toggle only RGR06's touchpad HID node.
$F5::ToggleRgr06Touchpad()

; Requested mapping: right-side single click -> mouse right click.
$Enter::Send "{RButton}"

; Requested mapping: left-side single click -> mouse left click.
; Repeated F3 pulses within the decision interval are treated as an unassigned
; left-side long press. The short-click response therefore has a small delay.
$F3:: {
    global LeftButtonPulseCount
    LeftButtonPulseCount += 1
    SetTimer(ResolveLeftButtonGesture, -280)
}
$F3 up::Return

; ---------------- Custom mappings ----------------
; These detected actions are intentionally disabled. Replace Return with a Send,
; Run, or function call when you decide what each gesture should do.
$F6::Return             ; 滚轮长按
$F8::Return             ; 滚轮三击
$Browser_Back::Return   ; 右侧键双击
$F2::Return             ; 右侧键长按
$F7::Return             ; 右侧键三击
; 左侧键长按 is handled by ResolveLeftButtonGesture() and does nothing.

#HotIf

ResolveLeftButtonGesture() {
    global LeftButtonPulseCount
    if LeftButtonPulseCount = 1 {
        Send "{LButton}"
    }
    LeftButtonPulseCount := 0
}

ToggleRgr06Touchpad() {
    global TouchpadToggleScript, TouchpadStatusFile
    try {
        if FileExist(TouchpadStatusFile) {
            FileDelete(TouchpadStatusFile)
        }
        command := 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' TouchpadToggleScript '" -StatusPath "' TouchpadStatusFile '"'
        exitCode := RunWait(command, , "Hide")
        state := FileExist(TouchpadStatusFile) ? Trim(FileRead(TouchpadStatusFile)) : "ERROR"
        if exitCode = 0 && state = "DISABLED" {
            TrayTip("RGR06 Mapper", "触摸板已禁用")
        } else if exitCode = 0 && state = "ENABLED" {
            TrayTip("RGR06 Mapper", "触摸板已启用")
        } else {
            TrayTip("RGR06 Mapper", "触摸板切换失败：" state)
        }
    } catch as err {
        TrayTip("RGR06 Mapper", "触摸板切换失败")
    }
}

TrayTip("RGR06 Mapper", "脚本已加载。按 Ctrl+Alt+R 开启映射。")

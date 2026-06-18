#Requires AutoHotkey v2.0

hook := InputHook("L0 T1")
hook.KeyOpt("{All}", "N")
hook.OnKeyDown := (*) => 0
hook.OnEnd := (*) => 0
hook.Start()
hook.Stop()
FileAppend("InputHook recording API OK`n", "*")
ExitApp

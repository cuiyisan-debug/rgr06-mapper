$ErrorActionPreference = 'Continue'

function Write-Step([string]$Message) {
  Write-Host "[bt-wake-fix] $Message"
}

$log = Join-Path $env:TEMP ("bt-wake-fix-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log")
Start-Transcript -Path $log -Force | Out-Null

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Step "Running as admin: $isAdmin"

Write-Step "Disable USB selective suspend for current power scheme"
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /S SCHEME_CURRENT

Write-Step "Enable wake for programmable HID keyboard/mouse/control devices"
$wakeDevices = powercfg /devicequery wake_programmable | Where-Object {
  $_ -match 'Keyboard|keyboard|Mouse|mouse|HID|Consumer|System|Vendor'
}
foreach ($device in $wakeDevices) {
  Write-Step "Enable wake: $device"
  powercfg /deviceenablewake "$device"
}

Write-Step "Find Intel Bluetooth adapter registry key"
$bt = Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue |
  Where-Object { $_.InstanceId -like 'USB\VID_8087&PID_0029*' -or $_.FriendlyName -like '*Wireless Bluetooth*' } |
  Select-Object -First 1
$btInstanceId = $null
if ($bt) {
  $btInstanceId = $bt.InstanceId
} else {
  $usbIntelBt = Get-ChildItem -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Enum\USB\VID_8087&PID_0029' -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($usbIntelBt) {
    $btInstanceId = 'USB\VID_8087&PID_0029\' + $usbIntelBt.PSChildName
  }
}

if ($btInstanceId) {
  $btKey = 'HKLM:\SYSTEM\CurrentControlSet\Enum\' + $btInstanceId
  $params = Join-Path $btKey 'Device Parameters'
  $d3Key = Join-Path $params 'e5b3b5ac-9725-4f78-963f-03dfb1d828c7'
  $wdfKey = Join-Path $params 'WDF'

  Write-Step "Bluetooth adapter instance: $btInstanceId"

  if (Test-Path -LiteralPath $params) {
    Write-Step "Set DeviceSelectiveSuspended=0"
    New-ItemProperty -LiteralPath $params -Name 'DeviceSelectiveSuspended' -PropertyType DWord -Value 0 -Force | Out-Null
  }

  if (Test-Path -LiteralPath $d3Key) {
    Write-Step "Set D3ColdSupported=0"
    New-ItemProperty -LiteralPath $d3Key -Name 'D3ColdSupported' -PropertyType DWord -Value 0 -Force | Out-Null
  }

  if (Test-Path -LiteralPath $wdfKey) {
    Write-Step "Set IdleInWorkingState=0"
    New-ItemProperty -LiteralPath $wdfKey -Name 'IdleInWorkingState' -PropertyType DWord -Value 0 -Force | Out-Null
  }
} else {
  Write-Step "Intel Bluetooth adapter not found"
}

Write-Step "Final wake-armed devices"
powercfg /devicequery wake_armed

Write-Step "Final USB selective suspend setting"
powercfg /query SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226

Write-Step "Log: $log"
Stop-Transcript | Out-Null

Write-Host ""
Write-Host "Repair commands completed. Reboot Windows, then test Bluetooth keyboard/mouse wake from sleep." -ForegroundColor Green
Write-Host "Log file: $log"
Read-Host "Press Enter to close"

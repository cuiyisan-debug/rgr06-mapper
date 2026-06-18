$ErrorActionPreference = 'Continue'

$log = Join-Path $env:TEMP ("bt-enablewake-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log")
Start-Transcript -Path $log -Force | Out-Null

function Try-EnableWake([string]$Name) {
  if ([string]::IsNullOrWhiteSpace($Name)) { return }
  Write-Host "[try-enablewake] $Name"
  powercfg /deviceenablewake "$Name"
  Write-Host "[exit-code] $LASTEXITCODE"
}

$targets = @(
  'Intel(R) Wireless Bluetooth(R)',
  '英特尔(R) 无线 Bluetooth(R)',
  'AULA-S98 5.2-1',
  'MX Master 2S',
  'RGR06',
  'Microsoft Bluetooth Enumerator',
  'Microsoft Bluetooth LE Enumerator',
  'Bluetooth LE Generic Attribute Service',
  'Bluetooth Low Energy GATT compliant HID device',
  '符合蓝牙低能耗 GATT 的 HID 设备',
  'USB Root Hub (USB 3.0)',
  'USB 根集线器(USB 3.0)',
  'Intel(R) USB 3.0 eXtensible Host Controller - 1.0 (Microsoft)',
  'Intel(R) USB 3.0 可扩展主机控制器 - 1.0 (Microsoft)'
)

foreach ($target in $targets) {
  Try-EnableWake $target
}

Write-Host "[wake_armed]"
powercfg /devicequery wake_armed

Write-Host "[log] $log"
Stop-Transcript | Out-Null
Read-Host "Press Enter to close"

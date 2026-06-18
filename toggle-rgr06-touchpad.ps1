param(
    [Parameter(Mandatory = $true)]
    [string]$StatusPath
)

$ErrorActionPreference = 'Stop'

try {
    $touchpads = Get-PnpDevice -Class HIDClass | Where-Object {
        $_.InstanceId -match 'VID&02248A_PID&045B' -and
        $_.InstanceId -match '&COL03' -and
        $_.FriendlyName -eq 'HID-compliant digitizer'
    }

    if (($touchpads | Measure-Object).Count -gt 1) {
        Set-Content -LiteralPath $StatusPath -Value 'MULTIPLE_FOUND' -Encoding ASCII
        exit 3
    }

    $touchpad = $touchpads | Select-Object -First 1

    if ($null -eq $touchpad) {
        Set-Content -LiteralPath $StatusPath -Value 'NOT_FOUND' -Encoding ASCII
        exit 2
    }

    if ($touchpad.Status -eq 'OK') {
        Disable-PnpDevice -InstanceId $touchpad.InstanceId -Confirm:$false
        Start-Sleep -Milliseconds 800
        $after = Get-PnpDevice -InstanceId $touchpad.InstanceId
        if ($after.Status -ne 'OK') {
            Set-Content -LiteralPath $StatusPath -Value ('DISABLED:' + $after.Status + ':' + $touchpad.InstanceId) -Encoding UTF8
        }
        else {
            Set-Content -LiteralPath $StatusPath -Value ('DISABLE_FAILED_STATUS_OK:' + $touchpad.InstanceId) -Encoding UTF8
            exit 4
        }
    }
    else {
        Enable-PnpDevice -InstanceId $touchpad.InstanceId -Confirm:$false
        Start-Sleep -Milliseconds 800
        $after = Get-PnpDevice -InstanceId $touchpad.InstanceId
        if ($after.Status -eq 'OK') {
            Set-Content -LiteralPath $StatusPath -Value ('ENABLED:' + $after.Status + ':' + $touchpad.InstanceId) -Encoding UTF8
        }
        else {
            Set-Content -LiteralPath $StatusPath -Value ('ENABLE_FAILED:' + $after.Status + ':' + $touchpad.InstanceId) -Encoding UTF8
            exit 5
        }
    }
}
catch {
    Set-Content -LiteralPath $StatusPath -Value ('ERROR: ' + $_.Exception.Message) -Encoding UTF8
    exit 1
}

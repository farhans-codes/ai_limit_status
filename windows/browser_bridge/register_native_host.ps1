param([switch]$Unregister)

$hostName = 'com.ailimitstatus.browser_bridge'
$registrations = @(
  @{ Key = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\$hostName"; Manifest = 'chromium-host.json' },
  @{ Key = "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\$hostName"; Manifest = 'chromium-host.json' },
  @{ Key = "HKCU:\Software\Mozilla\NativeMessagingHosts\$hostName"; Manifest = 'firefox-host.json' }
)

foreach ($registration in $registrations) {
  if ($Unregister) {
    Remove-Item -Path $registration.Key -Recurse -Force -ErrorAction SilentlyContinue
    continue
  }
  New-Item -Path $registration.Key -Force | Out-Null
  Set-Item -Path $registration.Key -Value (Join-Path $PSScriptRoot $registration.Manifest)
}

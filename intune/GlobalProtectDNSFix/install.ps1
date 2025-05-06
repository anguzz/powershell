$registryPath = "HKLM:\SOFTWARE\Palo Alto Networks\GlobalProtect\Settings"
if (-Not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force
}

# Create or update the registry key for DNS block method.
New-ItemProperty -Path $registryPath -Name "DNSBlockMethod" -Value 2 -PropertyType DWORD -Force

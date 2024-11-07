#  disable SSL certificate verification for Nitro PDF on remote machines.
#  necessary due to SSL/TLS interception replacing the default SSL certificates that Nitro uses for verification
#  change is based on a recommendation from Nitro support.

$computerName = Read-Host "Enter the machine name or IP address"  # Prompt for the target machine name or IP address
$credential = Get-Credential  # Prompt for administrative credentials

Invoke-Command -ComputerName $computerName -Credential $credential -ScriptBlock {
    # Check if the registry path exists; if not, it creates the necessary path.
    $regPath = "HKLM:\SOFTWARE\Nitro\PDF Pro\14\Settings\Curl"
    if (-Not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force
    }

    # Create or update the registry key to disable SSL verification.
    New-ItemProperty -Path $regPath -Name "ssl_verify_peer" -Value 0 -Propert

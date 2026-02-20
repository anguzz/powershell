Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ================= CONFIG =================
$PasswordPolicyInterval = 90
$domainEmailExtension = ""
$logoUrl = "https://avatars.githubusercontent.com/u/26943671?v=4"
# ==========================================

function Show-ResultPopup {
    param(
        [string]$Message
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Width = 900
    $form.Height = 190
    $form.Text = ""
    $form.ShowIcon = $false
    $form.StartPosition = "CenterScreen"
    $form.TopMost = $true

    $pictureBox = New-Object System.Windows.Forms.PictureBox
    $pictureBox.Width = 120
    $pictureBox.Height = 120
    $pictureBox.Location = New-Object System.Drawing.Point(10,10)
    $pictureBox.SizeMode = "StretchImage"
    $pictureBox.Image = [System.Drawing.Image]::FromStream(
        (New-Object System.Net.WebClient).OpenRead($logoUrl)
    )

    $linkLabel = New-Object System.Windows.Forms.LinkLabel
    $linkLabel.Font = New-Object System.Drawing.Font("Arial",12)
    $linkLabel.Location = New-Object System.Drawing.Point(140,40)
    $linkLabel.Width = 700
    $linkLabel.Height = 100
    $linkLabel.Text = $Message

    $url = "https://myaccount.microsoft.com"
    if ($Message -like "*$url*") {
        $urlStart = $Message.IndexOf($url)
        $linkLabel.LinkArea = New-Object System.Windows.Forms.LinkArea $urlStart, $url.Length
        $linkLabel.add_LinkClicked({ Start-Process $url })
    } else {
        $linkLabel.LinkBehavior = "NeverUnderline"
        $linkLabel.LinkColor = "Black"
    }

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(700,100)
    $okButton.Size = New-Object System.Drawing.Size(100,30)
    $okButton.Text = "OK"
    $okButton.Add_Click({ $form.Close() })

    $form.Controls.AddRange(@($pictureBox,$linkLabel,$okButton))
    $form.ShowDialog() | Out-Null
}

# ================= INPUT FORM =================


$inputForm = New-Object System.Windows.Forms.Form
$inputForm.ShowIcon = $false
$inputForm.Width = 520
$inputForm.Height = 220
$inputForm.Text = "Angel's Password Expiration Checker"
$inputForm.StartPosition = "CenterScreen"
$inputForm.TopMost = $true

# Logo
$logoUrl = "https://avatars.githubusercontent.com/u/26943671?v=4"

$pictureBox = New-Object System.Windows.Forms.PictureBox
$pictureBox.Width = 80
$pictureBox.Height = 80
$pictureBox.Location = New-Object System.Drawing.Point(20,20)
$pictureBox.SizeMode = "StretchImage"
$pictureBox.Image = [System.Drawing.Image]::FromStream(
    (New-Object System.Net.WebClient).OpenRead($logoUrl)
)

# Label
$label = New-Object System.Windows.Forms.Label
$label.Text = "Enter username (without domain):"
$label.Location = New-Object System.Drawing.Point(120,30)
$label.AutoSize = $true

# Textbox
$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Location = New-Object System.Drawing.Point(120,60)
$textBox.Width = 350

# Button
$submitButton = New-Object System.Windows.Forms.Button
$submitButton.Text = "Check"
$submitButton.Location = New-Object System.Drawing.Point(370,100)

$inputForm.Controls.AddRange(@(
    $pictureBox,
    $label,
    $textBox,
    $submitButton
))


$submitButton.Add_Click({

    $username = $textBox.Text.Trim()
    if (-not $username) { return }

    $inputForm.Close()

    $userPrincipalName = "$username$domainEmailExtension"

    try {
        Connect-MgGraph -Scopes "User.Read.All" -ErrorAction Stop

        $UserDetails = Get-MgUser -Filter "UserPrincipalName eq '$userPrincipalName'" `
            -Property "DisplayName,LastPasswordChangeDateTime,accountEnabled"

        if (-not $UserDetails) {
            Show-ResultPopup "User not found."
            return
        }

        if (-not $UserDetails.accountEnabled) {
            Show-ResultPopup "The account for $($UserDetails.DisplayName) is currently DISABLED."
            return
        }

        if (-not $UserDetails.LastPasswordChangeDateTime) {
            Show-ResultPopup "No password change date available."
            return
        }

        $lastChangeDate = [datetime]$UserDetails.LastPasswordChangeDateTime
        $daysSinceLastChange = (Get-Date) - $lastChangeDate
        $daysRemaining = $PasswordPolicyInterval - $daysSinceLastChange.Days - 1

        if ($daysRemaining -le 0) {
            Show-ResultPopup "The password for $($UserDetails.DisplayName) has EXPIRED.`n`nPlease update immediately at https://myaccount.microsoft.com"
        }
        elseif ($daysRemaining -le 14) {
            Show-ResultPopup "The password for $($UserDetails.DisplayName) will expire in $daysRemaining days.`n`nPlease update at https://myaccount.microsoft.com"
        }
        else {
            Show-ResultPopup "The password for $($UserDetails.DisplayName) is valid.`n`n$daysRemaining days remaining."
        }

        Disconnect-MgGraph
    }
    catch {
        Show-ResultPopup "Graph authentication failed or insufficient permissions."
    }
})

$inputForm.Controls.AddRange(@($label,$textBox,$submitButton))
$inputForm.ShowDialog() | Out-Null
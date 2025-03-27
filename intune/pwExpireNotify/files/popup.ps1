param(
    [int]$DaysRemaining  
) 

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Width = 830 
$form.Height = 190  
$form.Text = ""  
$form.ShowIcon = $false

$pictureBox = New-Object System.Windows.Forms.PictureBox
$pictureBox.Width = 100 
$pictureBox.Height = 100 
$pictureBox.Location = New-Object System.Drawing.Point(10, 10) 
$pictureBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::StretchImage
$pictureBox.Image = [System.Drawing.Image]::FromFile((Join-Path $PSScriptRoot "Logo.png"))

$linkLabel = New-Object System.Windows.Forms.LinkLabel
$linkLabel.AutoSize = $true  
$linkLabel.Font = New-Object System.Drawing.Font("Arial", 12)
$linkLabel.Location = New-Object System.Drawing.Point(140, 30) 

$currentUser = (Get-WmiObject Win32_Process -Filter "Name = 'explorer.exe'").GetOwner().User
$text = "Hi $currentUser, your password will expire in $DaysRemaining days.`n`nPlease update your password soon from any browser at https://myaccount.microsoft.com"

$linkLabel.Text = $text
$linkLabel.Width = 640  
$linkLabel.Height = 90  

$urlStart = $text.IndexOf('https://myaccount.microsoft.com') 
$urlLength = 'https://myaccount.microsoft.com'.Length
$linkLabel.LinkArea = New-Object System.Windows.Forms.LinkArea $urlStart, $urlLength
$linkLabel.add_LinkClicked({ Start-Process "https://myaccount.microsoft.com" })

$okButton = New-Object System.Windows.Forms.Button
$okButton.Location = New-Object System.Drawing.Point(700, 100)  
$okButton.Size = New-Object System.Drawing.Size(100, 30) 
$okButton.Text = "OK"
$okButton.Add_Click({ $form.Close() })  

$form.Controls.Add($pictureBox)
$form.Controls.Add($linkLabel)
$form.Controls.Add($okButton)  
$form.Add_Shown({$form.Activate()})
$form.ShowDialog() | Out-Null

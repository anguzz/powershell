Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Width = 850 
$form.Height = 175  
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
$linkLabel.Location = New-Object System.Drawing.Point(140, 50)
$linkLabel.Width = 700  
$linkLabel.Height = 150
$linkLabel.LinkBehavior = [System.Windows.Forms.LinkBehavior]::NeverUnderline
$linkLabel.LinkColor = [System.Drawing.Color]::Black

$currentUser = (Get-WmiObject Win32_Process -Filter "Name = 'explorer.exe'").GetOwner().User
$text = "Hi $currentUser, your account is currently locked. "

$linkLabel.Text = $text

$form.Controls.Add($pictureBox)
$form.Controls.Add($linkLabel)
$form.Add_Shown({$form.Activate()})
$form.ShowDialog() | Out-Null

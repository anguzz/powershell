param(
    [int]$DaysRemaining  #this gets passed in from checkExpire.ps1 
) 

Add-Type -AssemblyName System.Windows.Forms
$form = New-Object System.Windows.Forms.Form
$form.Width = 800 
$form.Height = 200  
$form.Text = "IT Department"

$linkLabel = New-Object System.Windows.Forms.LinkLabel
$linkLabel.AutoSize = $true  
$linkLabel.Font = New-Object System.Drawing.Font("Arial", 12)

$currentUser = $env:USERNAME

$text = "Hi $currentUser, Your password will expire in $DaysRemaining days.`n`n Please update your password soon from any browser at https://myaccount.microsoft.com"


$linkLabel.Text = $text
$linkLabel.Location = New-Object System.Drawing.Point(10, 50)
$linkLabel.Width = 780  
$linkLabel.Height = 150

$urlStart = $text.IndexOf('https://myaccount.microsoft.com') # Calculate the start position of the URL dynamically for the color that 

$urlLength = 'https://myaccount.microsoft.com'.Length
$linkLabel.LinkArea = New-Object System.Windows.Forms.LinkArea $urlStart, $urlLength
$linkLabel.add_LinkClicked({ Start-Process "https://myaccount.microsoft.com" })

$form.Controls.Add($linkLabel)
$form.Add_Shown({$form.Activate()})
$form.ShowDialog() | Out-Null

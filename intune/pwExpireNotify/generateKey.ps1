$KeyBytes = New-Object Byte[] 32    # 32 bytes = 256-bit key 
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($KeyBytes)
[Convert]::ToBase64String($KeyBytes)



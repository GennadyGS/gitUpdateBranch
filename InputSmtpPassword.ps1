Read-Host -AsSecureString | ConvertFrom-SecureString | Out-File $PSScriptRoot\SmtpPassword.txt

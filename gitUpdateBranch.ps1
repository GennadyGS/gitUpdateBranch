param(
    $remoteName = 'origin',
    $sourceBranchName = 'master'
)

$outputPath = "$PSScriptRoot\Output"
$timeSuffix = Get-Date -format yyyyMMddHHmmss
$logFileName = "$outputPath\gitUpdateBranch$timeSuffix.log"

. $PSScriptRoot\MailConfig.ps1
if (Test-Path "$PSScriptRoot\MailConfig.private.ps1") {
    . $PSScriptRoot\MailConfig.private.ps1
} 

Function RunGit {
    param (
        $gitArgsStr,
        [switch]$noCheck
    )

    Write-Host "git $gitArgsStr" -ForegroundColor yellow

    Invoke-Expression "git $gitArgsStr"
    if ((!$noCheck) -and  ($LastExitCode -ne 0)) {
        throw "'git $gitArgsStr' returned code $LastExitCode"
    }
}

Function ReportError {
    param (
        $errorText
    )

    . $PSScriptRoot\MailConfig.ps1
    if (Test-Path "$PSScriptRoot\MailConfig.private.ps1") {
        . $PSScriptRoot\MailConfig.private.ps1
    } 

    $credentials = New-Object Management.Automation.PSCredential $smtpUserName, ($smtpPassword | ConvertTo-SecureString)
    $body = "Workspace: $PWD`n" + "RemoteName: $remoteName`n" + "SourceBranchName: $sourceBranchName`n" + "Error message: `n$errorText"
    Send-MailMessage `
        -To $mailTo `
        -From $mailFrom `
        -Subject $mailSubject `
        -Priority High `
        -Body $body `
        -Attachments $logFileName `
        -SmtpServer $smtpServer `
        -Port $smtpServerPort `
        -Credential $credentials `
        -UseSsl `
        -Verbose
}

if (!(Test-Path -Path $outputPath))
{
    New-Item $outputPath -type directory | Out-Null
}

try {
    Write-Output "Starting transcription to $logFileName..."
    Start-Transcript -path $logFileName
}
catch {
    Write-Error "Error starting transcription: $_";
}

Write-Output "Current directory is $PWD"
try {
    try {
        RunGit "stash"
        RunGit "pull -p"
        RunGit "merge $remoteName/$sourceBranchName"
        RunGit "push"
        RunGit -noCheck "stash pop"
    }
    catch {
        Write-Error -ErrorRecord $Error[0]
        throw
    }
    finally {
        try{
            Stop-Transcript
        }
        catch {
            Write-Error "Error stopping transcription: $_";
        }
    }
}
catch {
    ReportError $_
}

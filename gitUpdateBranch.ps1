param(
    $remoteName = 'origin',
    $sourceBranchName = 'master',
    $targetBranchName
)

$outputPath = "$PSScriptRoot\Output"
$timeSuffix = Get-Date -format _yyyyMMdd_HHmmss
$logFileName = "$outputPath\gitUpdateBranch$timeSuffix.log"

Function RunGit {
    param (
        $gitArgsStr
    )

    Write-Host "git $gitArgsStr" -ForegroundColor yellow

    Invoke-Expression "git $gitArgsStr"
    if ($LastExitCode -ne 0) {
        throw "'git $gitArgsStr' returned code $LastExitCode"
    }
}

Function CheckGitStash {
    $gitStashOutput = RunGit "stash"
    $gitStashOutput | Write-Host
    return [bool] ($gitStashOutput | Select-String "HEAD is now at")
}

Function GetCurrentBranch {
    return [regex]::match((RunGit "status -b")[0], "On branch (.*)").Groups[1].Value
}

Function ReportError {
    param (
        $errorText
    )

    . $PSScriptRoot\MailConfig.ps1
    if (Test-Path "$PSScriptRoot\MailConfig.private.ps1") {
        . $PSScriptRoot\MailConfig.private.ps1
    } 
	if (Test-Path ".\MailConfig.private.ps1") {
		. .\MailConfig.private.ps1
	} 

    $credentials = New-Object Management.Automation.PSCredential $smtpUserName, ($smtpPassword | ConvertTo-SecureString)
    $body = "Workspace: $PWD`n" + "RemoteName: $remoteName`n" + "SourceBranchName: $sourceBranchName`n" + "TargetBranchName: $targetBranchName`n" + "Error message: `n$errorText"
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
        $changesShashed = CheckGitStash
        $currentBranch = GetCurrentBranch
        "current branch is $currentBranch"
        if ($targetBranchName -and ($currentBranch -ne $targetBranchName)) {
            RunGit "checkout $targetBranchName"
            $branchChanged = $true
        }
        RunGit "pull -p"
        RunGit "merge $remoteName/$sourceBranchName"
        RunGit "push"
        if ($branchChanged) {
            RunGit "checkout $currentBranch"
        }
        if ($changesShashed) {
            RunGit "stash pop"
        }
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

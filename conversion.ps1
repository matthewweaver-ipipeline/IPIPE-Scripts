$env:GITHUB_TOKEN = Get-Content ".\github_pat.txt"

$rootdir = "C:\iPipeline_Repos"
$scriptpath = $PWD.Path

$carrier = Read-Host "Enter the carrier name (e.g., 'LincolnFinancial')"


if (-not (Test-Path $rootdir)) {
    New-Item -ItemType Directory -Path $rootdir -Force | Out-Null
}

Set-Location $rootdir

$carrierlower = $carrier.ToLower()

git clone -b "feat/initialSetup" "https://www.github.com/ipipeline/igo-$carrierlower-serverless.git"

$repoPath = "$rootdir\igo-$carrierlower-serverless"

if (Test-Path -Path "$repoPath\trx-code") {
    Remove-Item -Path "$repoPath\trx-code" -Recurse -Force
}

if (Test-Path -Path "$repoPath\.github\agents") {
    Remove-Item -Path "$repoPath\.github\agents" -Recurse -Force
}

if (Test-Path -Path "$repoPath\.github\prompts") {
    Remove-Item -Path "$repoPath\.github\prompts" -Recurse -Force
}

if (Test-Path -Path "$repoPath\.github\copilot") {
    Remove-Item -Path "$repoPath\.github\copilot" -Recurse -Force
}

if (Test-Path -Path "$repoPath\.github\copilot-instructions.md") {
    Remove-Item -Path "$repoPath\.github\copilot-instructions.md" -Force
}

New-Item -ItemType Directory -Path "$repoPath\.github\agents" -Force | Out-Null
New-Item -ItemType Directory -Path "$repoPath\.github\prompts" -Force | Out-Null

Copy-Item -Path "$scriptpath\copilot-utils\setup-engine-bootstrap.md" -Destination "$repoPath\.github\agents\" -Force
Copy-Item -Path "$scriptpath\copilot-utils\setup-engine-context.md" -Destination "$repoPath\.github\agents\" -Force
Copy-Item -Path "$scriptpath\copilot-utils\ps-convert-trx-to-aws.prompt.md" -Destination "$repoPath\.github\prompts\" -Force

Set-Location $repoPath
copilot --prompt "@setup-engine-bootstrap" --model "claude-sonnet-4.6" --allow-all-tools --no-ask-user

if ($?) {
    Write-Host "Successfully executed setup-engine-bootstrap agent" -foregroundColor Green
}
else {
    Write-Host "Failed to execute setup-engine-bootstrap agent" -foregroundColor Red
    exit 1
}


Set-Location $repoPath
copilot --prompt "@setup-engine-context" --model "claude-sonnet-4.6" --allow-all-tools --no-ask-user

if ($?) {
    Write-Host "Successfully executed setup-engine-context agent" -foregroundColor Green
}
else {
    Write-Host "Failed to execute setup-engine-context agent" -foregroundColor Red
    exit 1
}

git clone "https://www.github.com/ipipeline/iGO-$carrier-WebServices.git" "$repoPath\trx-code"

Set-Location $repoPath
copilot --prompt "/ps-convert-trx-to-aws" --model "claude-sonnet-4.6" --allow-all-tools --no-ask-user

if ($?) {
    Write-Host "Successfully executed ps-convert-trx-to-aws prompt" -foregroundColor Green
}
else {
    Write-Host "Failed to execute ps-convert-trx-to-aws prompt" -foregroundColor Red
    exit 1
}


Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "      iGO Serverless Conversion Script" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/8] Loading GitHub token..." -ForegroundColor Yellow
$env:GITHUB_TOKEN = Get-Content ".\github_pat.txt"
$model = "claude-sonnet-4.6"
Write-Host "GitHub token loaded" -ForegroundColor Green

$rootdir = "C:\iPipeline_Repos"
$scriptpath = $PWD.Path

Write-Host ""
Write-Host "[2/8] Getting carrier and prompt information..." -ForegroundColor Yellow
$carrier = Read-Host "Enter the carrier name case sensitive (e.g. 'LincolnFinancial')"
$additionalPrompt = ""

$o = Read-Host "Do you have any additional prompt information to provide? (Y/N)"
if ($o -eq "Y") {
    $additionalPrompt = Read-Host "Enter additional prompt information"
}

Write-Host "Carrier name: $carrier" -ForegroundColor Green

Write-Host ""
Write-Host "[3/8] Setting up working directory..." -ForegroundColor Yellow
Write-Host "     Root directory: $rootdir" -ForegroundColor Gray

if (-not (Test-Path $rootdir)) {
    Write-Host "     Creating root directory..." -ForegroundColor Gray
    New-Item -ItemType Directory -Path $rootdir -Force | Out-Null
    Write-Host "Root directory created" -ForegroundColor Green
} else {
    Write-Host "Root directory exists" -ForegroundColor Green
}

Set-Location $rootdir

$carrierlower = $carrier.ToLower() -replace '_', '-'
Write-Host "Working directory set" -ForegroundColor Green
Write-Host ""
Write-Host "[4/8] Preparing serverless repository..." -ForegroundColor Yellow

if (Test-Path -Path "$rootdir\igo-$carrierlower-serverless") {
    Write-Host "	Directory igo-$carrierlower-serverless already exists" -ForegroundColor Yellow
    $q = Read-Host "     Remove it and continue? (Y/N)"
    if ($q -eq "Y") {
        Write-Host "     Removing existing directory..." -ForegroundColor Gray
        Remove-Item -Path "$rootdir\igo-$carrierlower-serverless" -Recurse -Force
        Write-Host "Directory removed" -ForegroundColor Green
    } else {
        Write-Host "Exiting script." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Directory path is clean" -ForegroundColor Green
}

Write-Host ""
Write-Host "     Selecting branch for serverless repo..." -ForegroundColor Gray
$branch = Read-Host "     Select branch (default: feat/initialSetup)"
if ([string]::IsNullOrWhiteSpace($branch)) {
	$branch = "feat/initialSetup"
}
Write-Host "     Branch: $branch" -ForegroundColor Gray
Write-Host "     Cloning repository..." -ForegroundColor Gray
git clone -b $branch "https://www.github.com/ipipeline/igo-$carrierlower-serverless.git"
if ($?) {
    Write-Host "Serverless repository cloned" -ForegroundColor Green
}  else {
    Write-Host "Failed to clone serverless repository" -ForegroundColor Red
    exit 1
}


$repoPath = "$rootdir\igo-$carrierlower-serverless"

Write-Host ""
Write-Host "[5/8] Setting up GitHub agent and prompt directories..." -ForegroundColor Yellow

if (-not (Test-Path -Path "$repoPath\.github\agents")) {
    Write-Host "     Creating .github/agents directory..." -ForegroundColor Gray
    New-Item -ItemType Directory -Path "$repoPath\.github\agents" -Force | Out-Null
    Write-Host ".github/agents created" -ForegroundColor Green
} else {
    Write-Host ".github/agents already exists" -ForegroundColor Green
}

if (-not (Test-Path -Path "$repoPath\.github\prompts")) {
    Write-Host "     Creating .github/prompts directory..." -ForegroundColor Gray
    New-Item -ItemType Directory -Path "$repoPath\.github\prompts" -Force | Out-Null
    Write-Host ".github/prompts created" -ForegroundColor Green
} else {
    Write-Host ".github/prompts already exists" -ForegroundColor Green
}

Write-Host ""
Write-Host "     Copying utility files..." -ForegroundColor Gray
#copy all utils necessary for conversion
Copy-Item -Path "$scriptpath\copilot-utils\setup-engine-bootstrap.md" -Destination "$repoPath\.github\agents\" -Force
Copy-Item -Path "$scriptpath\copilot-utils\setup-engine-context.md" -Destination "$repoPath\.github\agents\" -Force
Copy-Item -Path "$scriptpath\copilot-utils\security-agent.md" -Destination "$repoPath\.github\agents\" -Force
Copy-Item -Path "$scriptpath\copilot-utils\infrastructure-agent.md" -Destination "$repoPath\.github\agents\" -Force
Copy-Item -Path "$scriptpath\copilot-utils\documentation-agent.md" -Destination "$repoPath\.github\agents\" -Force
Copy-Item -Path "$scriptpath\copilot-utils\development-agent.md" -Destination "$repoPath\.github\agents\" -Force
Copy-Item -Path "$scriptpath\copilot-utils\ps-convert-trx-to-aws.prompt.md" -Destination "$repoPath\.github\prompts\" -Force
Write-Host "All utility files copied" -ForegroundColor Green

Write-Host ""
Write-Host "[6/8] Executing setup-engine-bootstrap agent..." -ForegroundColor Yellow
Write-Host "     This may take a few moments..." -ForegroundColor Gray

Set-Location $repoPath
copilot --prompt "@setup-engine-bootstrap" --model $model --allow-all-tools --no-ask-user

if ($?) {
    Write-Host "setup-engine-bootstrap agent completed successfully" -ForegroundColor Green
} else {
    Write-Host "setup-engine-bootstrap agent failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[7/8] Executing setup-engine-context agent..." -ForegroundColor Yellow
Write-Host "     This may take a few moments..." -ForegroundColor Gray

Set-Location $repoPath
copilot --prompt "@setup-engine-context" --model $model --allow-all-tools --no-ask-user

if ($?) {
    Write-Host "setup-engine-context agent completed successfully" -ForegroundColor Green
} else {
    Write-Host "setup-engine-context agent failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "     Cloning TRX WebServices repository..." -ForegroundColor Gray
New-Item -ItemType Directory -Path "$repoPath\trx-code" -Force | Out-Null
git clone "https://www.github.com/ipipeline/iGO-$carrier-WebServices.git" "$repoPath\trx-code"
if ($?) {
    Write-Host "TRX WebServices repository cloned" -ForegroundColor Green
} else {
    Write-Host "Failed to clone TRX WebServices repository" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[8/8] Executing TRX to AWS conversion..." -ForegroundColor Yellow
Write-Host "     Converting TRX code to AWS serverless format..." -ForegroundColor Gray

Set-Location $repoPath
git checkout -b "feat/initialConversion"
$promptFile = Join-Path $repoPath ".github\prompts\ps-convert-trx-to-aws.prompt.md"
$promptText = Get-Content $promptFile -Raw
copilot --prompt "$promptText $additionalPrompt" --model $model --allow-all-tools --no-ask-user

if ($?) {
    Write-Host "TRX to AWS conversion completed successfully" -ForegroundColor Green
} else {
    Write-Host "TRX to AWS conversion failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "     Cleaning up temporary AI files and directories..." -ForegroundColor Gray
#delete unneeded ai files and directories
if (Test-Path "$repoPath\.github\agents") {
    Remove-Item -Path "$repoPath\.github\agents" -Recurse -Force
    Write-Host "     .github/agents removed" -ForegroundColor Gray
}
if (Test-Path "$repoPath\.github\prompts") {
    Remove-Item -Path "$repoPath\.github\prompts" -Recurse -Force
    Write-Host "     .github/prompts removed" -ForegroundColor Gray
}
if (Test-Path "$repoPath\.github\copilot") {
    Remove-Item -Path "$repoPath\.github\copilot" -Recurse -Force
    Write-Host "     .github/copilot removed" -ForegroundColor Gray
}
if (Test-Path "$repoPath\.github\copilot-instructions.md") {
    Remove-Item -Path "$repoPath\.github\copilot-instructions.md" -Force
    Write-Host "     copilot-instructions.md removed" -ForegroundColor Gray
}
if (Test-Path "$repoPath\.github\AGENTS.md") {
    Remove-Item -Path "$repoPath\.github\AGENTS.md" -Force
    Write-Host "     AGENTS.md removed" -ForegroundColor Gray
}

Write-Host ""
Write-Host "===========================================" -ForegroundColor Green
Write-Host "    Conversion Complete!" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Converted repository location:" -ForegroundColor Green
Write-Host "  $repoPath" -ForegroundColor Cyan
Write-Host ""
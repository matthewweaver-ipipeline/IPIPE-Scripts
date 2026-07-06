$pat = "kldhjawfkaw"

$setupbootstrapurl = "https://raw.githubusercontent.com/ipipeline/github-copilot-collective/feat%2FSetupEngine/setup-engine-bootstrap.md"
$setupcontexturl = "https://raw.githubusercontent.com/ipipeline/github-copilot-collective/feat%2FSetupEngine/setup-engine-context.md"
$conversionprompturl = "https://raw.githubusercontent.com/ipipeline/igo-lincolnfinancial-serverless/dev/ps-convert-trx-to-aws.prompt.md"

$headers = @{
    "Authorization" = "Bearer $pat"
}


$carrier = Read-Host "Enter the carrier name (e.g., 'LincolnFinancial'): "

git clone "https://$pat@github.com/ipipeline/igo-${carrier.ToLower()}-serverless.git"

if (-not (Test-Path ".\.github\agents")) {
    New-Item -ItemType Directory -Path ".\.github\agents" -Force | Out-Null
}


Invoke-WebRequest -Uri $setupbootstrapurl -Headers $headers -OutFile ".\.github\agents\setup-engine-bootstrap.agent.md"
Invoke-WebRequest -Uri $setupcontexturl -Headers $headers -OutFile ".\.github\agents\setup-engine-context.agent.md"

if (-not (Test-Path ".\.github\prompts")) {
    New-Item -ItemType Directory -Path ".\.github\prompts" -Force | Out-Null
}

Invoke-WebRequest -Uri $conversionprompturl -Headers $headers -OutFile ".\.github\prompts\ps-convert-trx-to-aws.prompt.md"

copilot --agent setup-engine-bootstrap \
        --prompt "" \
        --allow-all-tools \
        --no-ask-user

if [ $? -eq 0 ]; then
    Write-Host "Successfully executed setup-engine-bootstrap agent" -foregroundColor Green
else
    Write-Host "Failed to execute setup-engine-bootstrap agent" -foregroundColor Red
    exit 1
fi

copilot --agent setup-engine-context \
        --prompt "" \
        --allow-all-tools \
        --no-ask-user

if [ $? -eq 0 ]; then
    Write-Host "Successfully executed setup-engine-context agent" -foregroundColor Green
else
    Write-Host "Failed to execute setup-engine-context agent" -foregroundColor Red
    exit 1
fi


if (-not (Test-Path ".\trx-code")) {
    New-Item -ItemType Directory -Path ".\trx-code" -Force | Out-Null
}

git clone "https://$pat@github.com/ipipeline/iGO-$carrier-WebServices.git"

copilot --prompt "/ps-convert-trx-to-aws" \
        --allow-all-tools \
        --no-ask-user

if [ $? -eq 0 ]; then
    Write-Host "Successfully executed ps-convert-trx-to-aws prompt" -foregroundColor Green
else
    Write-Host "Failed to execute ps-convert-trx-to-aws prompt" -foregroundColor Red
    exit 1
fi


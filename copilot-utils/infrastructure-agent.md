# Infrastructure & Deployment Agent

## Role
Infrastructure as Code (IaC) specialist for AWS Lambda serverless deployments using Terragrunt and Terraform with multi-environment orchestration.

## Reference Documentation
📖 **Primary Reference**: [.github/copilot-instructions.md](../copilot-instructions.md)

For comprehensive infrastructure details, see:
- **Infrastructure & Deployment**: [copilot-instructions.md § Infrastructure & Deployment](../copilot-instructions.md#infrastructure--deployment)
- **Deployment Workflows**: [copilot-instructions.md § Deployment Workflow](../copilot-instructions.md#deployment-workflow)
- **DevOps Principles**: [devops-core-principles.instructions.md](../instructions/devops-core-principles.instructions.md)

## My Specialized Focus
As the Infrastructure Agent, I focus on:
- Terragrunt/Terraform configuration and best practices
- Multi-environment deployment (sandbox → qa → uat → prod)
- Lambda optimization (memory, timeout, concurrency, warming)
- IAM policies and Parameter Store access
- CI/CD pipeline configuration (GitHub Actions)
- State management and locking

## Technology Stack

### Infrastructure as Code
- **Terragrunt**: 0.x (orchestration and DRY configuration)
- **Terraform**: 1.1.3-1.9.x (AWS resource provisioning)
- **Module**: `igo-ps-aws-lambda-application-module` v1.2.4
- **State Backend**: S3 with DynamoDB locking

### AWS Services
- AWS Lambda (Node.js 22.x runtime)
- API Gateway (REST API with OpenAPI 3.0)
- Systems Manager Parameter Store (credentials)
- CloudWatch Logs (logging)
- SNS (alerting)
- IAM (roles and policies)
- Lambda Layers (shared utilities)

## Directory Structure

```
igo-democarrier-serverless/
├── applied/
│   └── accounts/
│       ├── sandbox/
│       │   └── us-east-1/
│       │       ├── common.tfvars         # Shared environment config
│       │       ├── terragrunt.hcl        # S3 backend + worker role
│       │       ├── core/
│       │       │   └── terragrunt.hcl    # VPC, subnets, security groups
│       │       └── demo-carrier-api/
│       │           └── terragrunt.hcl    # Lambda configs + env vars
│       ├── qa/
│       │   └── us-east-1/
│       │       ├── common.tfvars
│       │       ├── terragrunt.hcl
│       │       ├── core/
│       │       └── demo-carrier-api/
│       ├── uat/
│       │   └── us-east-1/
│       │       ├── common.tfvars
│       │       ├── terragrunt.hcl
│       │       ├── core/
│       │       └── demo-carrier-api/
│       └── prod/
│           └── us-east-1/
│               ├── common.tfvars
│               ├── terragrunt.hcl
│               ├── core/
│               └── demo-carrier-api/
├── infrastructure/
│   └── region/
│       ├── core/
│       │   ├── main.tf              # Core infrastructure
│       │   ├── variables.tf
│       │   └── versions.tf
│       └── demo-carrier-api/
│           ├── main.tf              # Lambda module configuration
│           ├── variables.tf         # Input variables
│           ├── versions.tf          # Provider version constraints
│           └── README.md            # API documentation
└── demo-carrier-api/
    ├── src/                         # Lambda source code
    └── package.json
```

## Terragrunt Configuration

### State Management Configuration

**File**: `applied/accounts/{env}/us-east-1/terragrunt.hcl`

```hcl
remote_state {
  backend = "s3"
  config = {
    bucket         = "us-east-1-${get_aws_account_id()}-democarrier-savedstate"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock-table"
    role_arn       = "arn:aws:iam::${get_aws_account_id()}:role/democarrier-worker-role"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

iam_role = "arn:aws:iam::${get_aws_account_id()}:role/democarrier-worker-role"

terraform {
  extra_arguments "common_vars" {
    commands = get_terraform_commands_that_need_vars()
    
    optional_var_files = [
      "${get_parent_terragrunt_dir()}/common.tfvars"
    ]
  }
}
```

### Common Environment Variables

**File**: `applied/accounts/{env}/us-east-1/common.tfvars`

```hcl
region         = "us-east-1"
account_id     = "239494761538"  # Sandbox account
environment    = "sandbox"
carrier_name   = "democarrier"

tags = {
  Environment = "sandbox"
  Project     = "iGO Demo Carrier API"
  ManagedBy   = "Terragrunt"
  Team        = "PS iGO"
}
```

### Lambda Configuration

**File**: `applied/accounts/{env}/us-east-1/demo-carrier-api/terragrunt.hcl`

```hcl
terraform {
  source = "../../../../..//infrastructure/region/demo-carrier-api/"
}

include {
  path = find_in_parent_folders()
}

inputs = {
    api_stage_name = "api"

    # Environment variables for getWeather Lambda
    environment_vars_getWeather = {
        AWS                 = true
        LOG_LEVEL_MAPPING   = "INFO"      # DEBUG in sandbox, INFO+ in prod
        RETRYCOUNT          = 3           # Number of retry attempts
        TIMEOUT             = 3000        # Request timeout (milliseconds)
        ALLOW_LOAD_TESTS    = true        # Enable mock handlers
        LAMBDA_WARMER       = true        # Keep Lambda warm
        ALLOWED_ORIGIN_LIST = "http://localhost,https://local.ipipeline.com"
    }

    # Environment variables for getSoap Lambda
    environment_vars_getSoap = {
        AWS                 = true
        LOG_LEVEL_MAPPING   = "INFO"
        RETRYCOUNT          = 3
        TIMEOUT             = 3000
        ALLOW_LOAD_TESTS    = true
        LAMBDA_WARMER       = true
        ALLOWED_ORIGIN_LIST = "http://localhost,https://local.ipipeline.com"
    }
    
    # SNS alert configuration
    alert_emails = ["team@ipipeline.com"]
    deploy_emails = ["deployments@ipipeline.com"]
}
```

## Terraform Module Configuration

### Lambda Module Setup

**File**: `infrastructure/region/demo-carrier-api/main.tf`

```hcl
terraform {
  required_version = ">= 1.1.3, < 1.10"
}

data "aws_lambda_layer_version" "proservices_helper_version" {
  layer_name = "proservices_helper"
}

data "aws_lambda_layer_version" "ps_nodejs_modules_version" {
  layer_name = "ps_nodejs_modules"
}

module "lambda_api" {
  source  = "git::https://github.com/ipipeline/igo-ps-aws-lambda-application-module.git?ref=v1.2.4"
  
  app_name = "demo-carrier-api"
  
  lambda_props = [
    {
      "function_name"                  = "ps-igo-democarrier-getWeather"
      "lambda_description"             = "Demo Carrier API - Get Weather Data"
      "handler"                        = "src/handlers/getWeather.handler"
      "source_path"                    = "${path.module}/../../..//demo-carrier-api"
      "runtime"                        = "nodejs22.x"
      "environment_variables"          = var.environment_vars_getWeather
      "memory_size"                    = null  # Use default (128 MB)
      "timeout"                        = null  # Use default (3 seconds)
      "reserved_concurrent_executions" = null  # No concurrency limit
      "retention_days"                 = null  # Use default (14 days)
      "warm"                           = tobool(var.environment_vars_getWeather.LAMBDA_WARMER)
      
      "layers" = [
        data.aws_lambda_layer_version.proservices_helper_version.arn,
        data.aws_lambda_layer_version.ps_nodejs_modules_version.arn
      ]
    },
    {
      "function_name"                  = "ps-igo-democarrier-getSoap"
      "lambda_description"             = "Demo Carrier API - Get SOAP Data"
      "handler"                        = "src/handlers/getSoap.handler"
      "source_path"                    = "${path.module}/../../..//demo-carrier-api"
      "runtime"                        = "nodejs22.x"
      "environment_variables"          = var.environment_vars_getSoap
      "memory_size"                    = null
      "timeout"                        = null
      "reserved_concurrent_executions" = null
      "retention_days"                 = null
      "warm"                           = tobool(var.environment_vars_getSoap.LAMBDA_WARMER)
      
      "layers" = [
        data.aws_lambda_layer_version.proservices_helper_version.arn,
        data.aws_lambda_layer_version.ps_nodejs_modules_version.arn
      ]
    }
  ]
  
  # API Gateway configuration
  openapi_spec_path = "${path.module}/../../..//demo-carrier-api/src/apiSpec.yaml"
  api_stage_name    = var.api_stage_name
  
  # Parameter Store access
  paramstore_names = [
    "/ProfService/democarrier/getWeather",
    "/ProfService/democarrier/getSoap"
  ]
  
  # SNS alerting
  alert_emails  = var.alert_emails
  deploy_emails = var.deploy_emails
  
  # Common tags
  tags = var.tags
}
```

### Variable Definitions

**File**: `infrastructure/region/demo-carrier-api/variables.tf`

```hcl
variable "environment_vars_getWeather" {
  type        = map(string)
  description = "Environment variables for getWeather Lambda function"
}

variable "environment_vars_getSoap" {
  type        = map(string)
  description = "Environment variables for getSoap Lambda function"
}

variable "api_stage_name" {
  type        = string
  description = "API Gateway stage name"
  default     = "api"
}

variable "alert_emails" {
  type        = list(string)
  description = "Email addresses for API alerts"
}

variable "deploy_emails" {
  type        = list(string)
  description = "Email addresses for deployment notifications"
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}
```

## Lambda Configuration

### Environment Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `AWS` | boolean | true | Enable AWS-specific features |
| `LOG_LEVEL_MAPPING` | string | INFO | Logging level (DEBUG, INFO, WARN, ERROR) |
| `RETRYCOUNT` | number | 3 | Number of API retry attempts |
| `TIMEOUT` | number | 3000 | Request timeout in milliseconds |
| `ALLOW_LOAD_TESTS` | boolean | true | Enable mock handlers for load testing |
| `LAMBDA_WARMER` | boolean | true | Enable Lambda warming to reduce cold starts |
| `ALLOWED_ORIGIN_LIST` | string | "" | Comma-separated list of allowed CORS origins |

### Lambda Layer Management

Lambda layers are managed via data sources (always use latest version):

```hcl
data "aws_lambda_layer_version" "proservices_helper_version" {
  layer_name = "proservices_helper"  # psHelper, LogHelperV2, securityHelper, snsHelper
}

data "aws_lambda_layer_version" "ps_nodejs_modules_version" {
  layer_name = "ps_nodejs_modules"   # Common npm dependencies
}
```

**Layer Update Process**:
1. Update layer code in `igo-ps-global-lambdas` repository
2. Publish new layer version to AWS
3. Lambda functions automatically use latest version on next deployment

### Lambda Performance Tuning

```hcl
{
  "memory_size"                    = 256      # Increase for CPU-intensive tasks
  "timeout"                        = 30       # Increase for long-running tasks
  "reserved_concurrent_executions" = 10       # Limit concurrent executions
  "retention_days"                 = 30       # CloudWatch log retention
  "warm"                           = true     # Enable Lambda warming
}
```

**Memory Sizing Guidelines**:
- 128 MB: Simple API calls (default)
- 256 MB: JSON parsing, moderate logic
- 512 MB: Heavy data processing
- 1024 MB+: Large file processing, complex transformations

**Timeout Guidelines**:
- 3 seconds: Default for simple API calls
- 10 seconds: Multiple external API calls
- 30 seconds: Complex processing
- 60 seconds: Maximum for API Gateway integration

## IAM Permissions

### Lambda Execution Role

Module automatically creates IAM role with:
- CloudWatch Logs write permissions
- Parameter Store read access (specified paths)
- SNS publish permissions
- VPC access (if configured)

### Parameter Store Access Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": [
        "arn:aws:ssm:us-east-1:*:parameter/ProfService/democarrier/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt"
      ],
      "Resource": "arn:aws:kms:us-east-1:*:key/*"
    }
  ]
}
```

### SNS Publish Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sns:Publish"
      ],
      "Resource": [
        "arn:aws:sns:us-east-1:*:ps-igo-democarrier-api-alerts",
        "arn:aws:sns:us-east-1:*:ps-igo-democarrier-deploy-alerts"
      ]
    }
  ]
}
```

## Deployment Workflows

### Local Deployment (Manual)

```powershell
# Navigate to specific environment
cd applied/accounts/sandbox/us-east-1/demo-carrier-api

# Initialize Terragrunt (first time only)
terragrunt init

# Preview changes
terragrunt plan

# Apply changes (requires approval)
terragrunt apply

# View output
terragrunt output

# Destroy infrastructure (DANGER - use with extreme caution)
# terragrunt destroy
```

### CI/CD Deployment (Automated)

#### GitHub Actions Workflow Structure

```
.github/workflows/
├── pull_request_dev_actions.yml      # PR to dev → auto-deploy sandbox+qa
├── pr_merge_main_actions.yml         # Merge to main → manual dispatch uat/prod
├── schedule_deploy.yml               # Scheduled deployments (if configured)
└── schedule_deploy_prod.yml          # Scheduled prod deployments (if configured)
```

#### Pull Request Workflow

**File**: `.github/workflows/pull_request_dev_actions.yml`

```yaml
name: Pull Request Dev Actions

on:
  pull_request:
    types: [opened, synchronize, reopened]
    branches:
      - dev
      - 'release/**'

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: false

jobs:
  pullrequest:
    uses: ipipeline/igo-ps-devops/.github/workflows/pull-request-actions.yml@v2
    with:
      PATHS_TO_LAMBDA: "['demo-carrier-api']"
      ENVIRONMENTS_TO_DEPLOY: |
        [
          {
            "workspace": "sandbox",
            "directory": "./applied/accounts/sandbox/us-east-1/demo-carrier-api/",
            "roleARN": "arn:aws:iam::239494761538:role/democarrier-worker-role"
          },
          {
            "workspace": "qa",
            "directory": "./applied/accounts/qa/us-east-1/demo-carrier-api/",
            "roleARN": "arn:aws:iam::119662755212:role/igopsdemoqa_proxy_role"
          }
        ]
    secrets: inherit
```

**Workflow Steps**:
1. Linting and code quality checks
2. Jest unit tests with coverage
3. Terragrunt plan for sandbox
4. Auto-deploy to sandbox (if tests pass)
5. Terragrunt plan for QA
6. Auto-deploy to QA (if sandbox successful)

#### Merge to Main Workflow

**File**: `.github/workflows/pr_merge_main_actions.yml`

```yaml
name: PR Merge Main Actions

on:
  pull_request:
    types: [closed]
    branches:
      - main

jobs:
  merge_main:
    if: github.event.pull_request.merged == true
    uses: ipipeline/igo-ps-devops/.github/workflows/pull-request-actions.yml@v2
    with:
      PATHS_TO_LAMBDA: "['demo-carrier-api']"
      ENVIRONMENTS_TO_DEPLOY: |
        [
          {
            "workspace": "uat",
            "directory": "./applied/accounts/uat/us-east-1/demo-carrier-api/",
            "roleARN": "arn:aws:iam::XXXXXXXX:role/democarrier-worker-role"
          },
          {
            "workspace": "prod",
            "directory": "./applied/accounts/prod/us-east-1/demo-carrier-api/",
            "roleARN": "arn:aws:iam::YYYYYYYY:role/democarrier-worker-role"
          }
        ]
      REQUIRE_MANUAL_APPROVAL: true
    secrets: inherit
```

**Workflow Steps**:
1. Terragrunt plan for UAT
2. Manual approval required (security gate)
3. Deploy to UAT
4. Terragrunt plan for PROD
5. Manual approval required (security gate)
6. Deploy to PROD

### Deployment Best Practices

#### Pre-Deployment Checklist

- [ ] Unit tests pass locally (`npm test`)
- [ ] Linting passes (`npm run lint`)
- [ ] No hardcoded credentials
- [ ] Environment variables configured in all environments
- [ ] Parameter Store entries created in target account
- [ ] OpenAPI spec updated (if adding endpoints)
- [ ] Documentation updated

#### Post-Deployment Validation

- [ ] Lambda functions deployed successfully
- [ ] API Gateway endpoints accessible
- [ ] CloudWatch Logs receiving logs
- [ ] SNS alerts configured
- [ ] Postman tests pass
- [ ] No errors in CloudWatch Logs
- [ ] Performance metrics acceptable

## Adding New Endpoints (Infrastructure)

### Step-by-Step Infrastructure Changes

#### 1. Update Terraform Module

**File**: `infrastructure/region/demo-carrier-api/main.tf`

Add to `lambda_props` array:

```hcl
{
  "function_name"                  = "ps-igo-democarrier-newEndpoint"
  "lambda_description"             = "Demo Carrier API - New Endpoint Description"
  "handler"                        = "src/handlers/newEndpoint.handler"
  "source_path"                    = "${path.module}/../../..//demo-carrier-api"
  "runtime"                        = "nodejs22.x"
  "environment_variables"          = var.environment_vars_newEndpoint
  "memory_size"                    = null
  "timeout"                        = null
  "reserved_concurrent_executions" = null
  "retention_days"                 = null
  "warm"                           = tobool(var.environment_vars_newEndpoint.LAMBDA_WARMER)
  
  "layers" = [
    data.aws_lambda_layer_version.proservices_helper_version.arn,
    data.aws_lambda_layer_version.ps_nodejs_modules_version.arn
  ]
}
```

Add to `paramstore_names`:

```hcl
paramstore_names = [
  "/ProfService/democarrier/getWeather",
  "/ProfService/democarrier/getSoap",
  "/ProfService/democarrier/newEndpoint"  # Add this line
]
```

#### 2. Add Variable Definition

**File**: `infrastructure/region/demo-carrier-api/variables.tf`

```hcl
variable "environment_vars_newEndpoint" {
  type        = map(string)
  description = "Environment variables for newEndpoint Lambda function"
}
```

#### 3. Configure All Environments

Update **each** environment's terragrunt.hcl:
- `applied/accounts/sandbox/us-east-1/demo-carrier-api/terragrunt.hcl`
- `applied/accounts/qa/us-east-1/demo-carrier-api/terragrunt.hcl`
- `applied/accounts/uat/us-east-1/demo-carrier-api/terragrunt.hcl`
- `applied/accounts/prod/us-east-1/demo-carrier-api/terragrunt.hcl`

Add to `inputs` block:

```hcl
environment_vars_newEndpoint = {
    AWS                 = true
    LOG_LEVEL_MAPPING   = "INFO"
    RETRYCOUNT          = 3
    TIMEOUT             = 3000
    ALLOW_LOAD_TESTS    = true
    LAMBDA_WARMER       = true
    ALLOWED_ORIGIN_LIST = "http://localhost,https://local.ipipeline.com"
}
```

#### 4. Create Parameter Store Entries

For **each** AWS account (sandbox, qa, uat, prod):

**AWS Console** → Systems Manager → Parameter Store → Create parameter:
- **Name**: `/ProfService/democarrier/newEndpoint`
- **Type**: SecureString
- **KMS Key**: Default or custom
- **Value**:
```json
{
  "credentials": {
    "client_id": "your-oauth-client-id",
    "client_secret": "your-oauth-client-secret",
    "endpoint": "https://auth.example.com/oauth/token"
  },
  "endpoint": "https://api.example.com/your-api"
}
```

#### 5. Update OpenAPI Spec

**File**: `demo-carrier-api/src/apiSpec.yaml`

```yaml
/democarrier/v1/newEndpoint:
  get:
    description: Your endpoint description
    parameters:
      - name: x-ipipeline-loadtest
        in: header
        schema:
          type: string
      - name: x-iPipeline-tracking-id
        in: header
        schema:
          type: string
    x-amazon-apigateway-integration:
      uri: ${ps-igo-democarrier-newEndpoint-lambda}
      passthroughBehavior: "when_no_match"
      httpMethod: "POST"
      type: "aws_proxy"
      responses:
          default:
            statusCode: "200"
    responses:
      "200":
        description: OK
    security: 
    - ping-authorizer: []
```

#### 6. Deploy and Validate

```powershell
# Local validation
cd applied/accounts/sandbox/us-east-1/demo-carrier-api
terragrunt plan

# Deploy via PR (automated)
git checkout -b feat/new-endpoint
git add .
git commit -m "feat: add newEndpoint API integration"
git push origin feat/new-endpoint
# Create PR to dev branch
```

## Monitoring & Debugging

### CloudWatch Logs

**Log Groups**: `/aws/lambda/ps-igo-democarrier-{functionName}`

```powershell
# View logs (AWS CLI)
aws logs tail /aws/lambda/ps-igo-democarrier-getWeather --follow

# Filter logs by tracking ID
aws logs filter-log-events `
    --log-group-name /aws/lambda/ps-igo-democarrier-getWeather `
    --filter-pattern "test-tracking-id-123"
```

### Splunk Queries

- **QA**: `index=igo_aws_webservice_qa source=*democarrier*`
- **UAT**: `index=igo_aws_webservice_uat source=*democarrier*`
- **PROD**: `index=igo_aws_webservice_prod source=*democarrier*`

### SNS Alerts

**Topics**:
- `ps-igo-democarrier-api-alerts` - Lambda errors, API failures
- `ps-igo-democarrier-deploy-alerts` - Deployment notifications

**Alert Configuration** (terragrunt.hcl):
```hcl
alert_emails  = ["team@ipipeline.com"]
deploy_emails = ["deployments@ipipeline.com"]
```

### Common Issues & Solutions

#### Issue: Terragrunt state lock conflict
**Solution**: 
```powershell
# Wait for other workflows to complete, or force unlock (last resort)
terragrunt force-unlock <lock-id>
```

#### Issue: Lambda cold starts affecting performance
**Solution**: 
```hcl
environment_vars_getWeather = {
    LAMBDA_WARMER = true  # Enable Lambda warming
}
```

#### Issue: Parameter Store access denied
**Solution**: 
- Verify parameter exists in target account
- Check IAM role has `ssm:GetParameter` permission
- Verify parameter name matches `paramstore_names` in main.tf

#### Issue: Lambda timeout errors
**Solution**: 
```hcl
{
  "timeout" = 30  # Increase from default 3 seconds
}
```

#### Issue: API Gateway 5xx errors
**Solution**: 
- Check CloudWatch Logs for Lambda errors
- Verify Lambda has correct permissions
- Check API Gateway integration configuration

## Terraform Best Practices

### Do's ✅

- Use Terragrunt for DRY configuration across environments
- Pin module versions (`?ref=v1.2.4`)
- Use data sources for Lambda layers (always latest)
- Store state in S3 with DynamoDB locking
- Use separate AWS accounts per environment
- Tag all resources consistently
- Use `terragrunt plan` before `apply`
- Configure state backend with encryption
- Use IAM roles for authentication (not access keys)
- Document infrastructure changes in PR descriptions

### Don'ts ❌

- Never commit credentials to Git
- Don't modify `common.tfvars` without team approval
- Don't skip `terragrunt plan` before `apply`
- Don't force-unlock state without investigating
- Don't deploy directly to prod (use CI/CD)
- Don't use wildcard IAM permissions
- Don't hardcode account IDs (use variables)
- Don't skip environment variable configuration
- Don't deploy without validating in sandbox first
- Don't use `terraform` commands directly (use `terragrunt`)

## Version Constraints

### Terragrunt Version
```hcl
# Minimum: 0.x
# Recommended: Latest 0.x release
```

### Terraform Version
```hcl
terraform {
  required_version = ">= 1.1.3, < 1.10"
}
```

### Provider Versions
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

## Completing Work: PR Workflow

After infrastructure changes, follow the standard PR workflow:

📖 **Complete Workflow Guide**: [../prompts/agent-pr-workflow.prompt.md](../prompts/agent-pr-workflow.prompt.md)

### Infrastructure-Specific Validation

**Before creating PR**:
```powershell
# 1. Validate Terraform syntax
cd applied/accounts/sandbox/us-east-1/demo-carrier-api
terragrunt validate

# 2. Preview changes (dry run)
terragrunt plan

# 3. Check for hardcoded values
cd c:\iPipeline_Repos\igo-democarrier-serverless
git diff | Select-String -Pattern "(account|arn:|i-[0-9a-f]{8})" -Context 2
```

### Infrastructure-Specific PR Checklist
- [ ] `terragrunt validate` passes
- [ ] `terragrunt plan` shows expected changes
- [ ] No hardcoded account IDs or ARNs
- [ ] Environment variables updated in ALL environments
- [ ] Parameter Store paths documented
- [ ] IAM policies follow least privilege
- [ ] Resource tagging is consistent
- [ ] State backend configured correctly
- [ ] Lambda memory/timeout appropriate
- [ ] Alert emails configured

### PR Description Template for Infrastructure

**Include in PR**:
```markdown
## Infrastructure Changes
**Environments Affected**: [sandbox/qa/uat/prod]
**Resource Changes**:
- [ ] Lambda configuration: [describe]
- [ ] IAM policies: [describe]
- [ ] Environment variables: [list changes]
- [ ] Parameter Store: [list new/updated keys]

## Terragrunt Plan Output
```
[Paste relevant plan output]
```

## Deployment Impact
- **Downtime**: [Yes/No - duration]
- **Rollback Plan**: [describe]
- **Monitoring**: [metrics to watch]

## Testing
- [ ] Deployed to sandbox
- [ ] Smoke tests passed
- [ ] Monitoring validated
```

**PR Title Examples**:
- `chore: increase Lambda memory to 256MB for performance`
- `feat: add Redis Parameter Store configuration`
- `fix: correct IAM policy for Parameter Store access`

## Related Agents

- 🏗️ [Development Agent](development-agent.md) - Lambda code patterns
- 🔒 [Security Agent](security-agent.md) - IAM policies and Parameter Store
- 🧪 [Testing Agent](testing-agent.md) - Sandbox validation
- 📝 [Documentation Agent](documentation-agent.md) - Infrastructure documentation

---

**Version**: 1.1.0
**Last Updated**: December 10, 2025

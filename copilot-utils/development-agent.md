# Development Agent

## Role
Expert AWS Lambda serverless developer specializing in Node.js 22.x REST APIs with deep knowledge of the iGO Demo Carrier integration patterns.

## Reference Documentation
📖 **Primary Reference**: [.github/copilot-instructions.md](../copilot-instructions.md)

For comprehensive details, see:
- **Technology Stack**: [copilot-instructions.md § Technology Stack](../copilot-instructions.md#technology-stack)
- **Architecture & Data Flow**: [copilot-instructions.md § Architecture & Data Flow](../copilot-instructions.md#architecture--data-flow)
- **Common Patterns**: [copilot-instructions.md § Common Patterns & Examples](../copilot-instructions.md#common-patterns--examples)
- **Development Guidelines**: [copilot-instructions.md § Development Guidelines](../copilot-instructions.md#development-guidelines)

## My Specialized Focus
As the Development Agent, I focus on:
- Implementing AWS Lambda function code following established patterns
- Ensuring handler/utility separation is maintained
- Applying retry logic and error handling patterns
- Integrating REST and SOAP APIs with proper OAuth flows
- Maintaining code quality and consistency with project standards

## Code Organization Principles

📖 **See**: [copilot-instructions.md § Code Organization](../copilot-instructions.md#code-organization)

### Key Principles (Summary)
- **Handler/Utility Separation**: Handlers are bare-bones wrappers; all logic in utilities
- **Handler Responsibilities**: XSS sanitization, lambda warming, call utilities, apply security headers
- **Handlers Do Not**: Contain business logic, API calls, error handling, request payload validation or processing
- **Utility Responsibilities**: Business logic, API calls, error handling, 80%+ test coverage
- **File Structure**: `src/handlers/` (entry points), `src/utils/` (logic + tests), `src/mocks/` (load testing)

## Standard Patterns

### 1. Lambda Handler Pattern (DO NOT MODIFY)

```javascript
const { psHelper, LogHelperV2, securityHelper } = require('/opt/nodejs/psUtils');
const apiUtil = require('../utils/callAPI');
const xssFilters = require('xss-filters'); // Import in handler for Checkmarx detection

exports.handler = async (event, context) => {
    let response;
    const logHelper = new LogHelperV2();
    try {
        const safeEvent = JSON.parse(xssFilters.inHTMLData(JSON.stringify(event)));
        if (safeEvent.job === "lambda-warmer") {
            logHelper.info(safeEvent);
            return "warmed";
        }
        response = await apiUtil.callAPI(safeEvent, psHelper, logHelper);
    } catch (err) {
        logHelper.error(JSON.stringify(err));
        return err;
    }
    response.headers = securityHelper.getSecurityHeaders(response.headers);
    logHelper.info(`Response from: ${event.path} StatusCode: ${response.statusCode} Body: ${response.body}`);
    const safeResponse = JSON.parse(xssFilters.inHTMLData(JSON.stringify(response)));
    return safeResponse;
};
```

📖 **Full Implementation**: [copilot-instructions.md § Utility Function Pattern (REST API with OAuth)](../copilot-instructions.md#utility-function-pattern-rest-api-with-oauth)

**Key Components**:
- Parameter Store credential retrieval
- OAuth token acquisition with load test support
- Axios instance with retry interceptor
- CORS validation
- Error handling with SNS alerts
- Tracking ID propagation

### 3. Axios Retry Interceptor Pattern

**Critical pattern** used in all REST API calls:

```javascript
instance.interceptors.response.use(
    function(response) {
        // Success: 2xx status codes
        logHelper.info(`method=${response.config.method} url=${response.config.url} status=${response.status}`);
        return response;
    },
    async function axiosRetryInterceptor(error) {
        let config = error.config;
        let errorMsg = { StatusCode: 0, Details: "" };
        
        // Parse error details
        if (error.response) {
            errorMsg.StatusCode = error.response.status;
            errorMsg.Details = inspect(error.response.data);
        } else if (error.message) {
            errorMsg.Details = inspect(error.message);
        } else {
            errorMsg.Details = inspect(error);
        }
        
        // Don't retry 4xx errors (except 401) or 2xx/3xx
        if (error.response && !shouldRetry(error.response.status)) {
            return Promise.reject(errorMsg);
        }
        
        // Check retry count
        config.__retryCount = config.__retryCount || 1;
        if (config.__retryCount >= config.retry) {
            return Promise.reject(errorMsg);
        }
        config.__retryCount += 1;
        
        logHelper.error(inspect(errorMsg));
        
        // Exponential backoff: 100ms delay
        const backoff = new Promise(resolve => setTimeout(resolve, 100));
        await backoff;
        
        logHelper.info(`Calling API - ${config.__retryCount} of ${config.retry}`);
        return instance(config);
    }
);
```

**shouldRetry() logic**:
```javascript
exports.shouldRetry = (_statusCode) => {
    if (_statusCode >= 500) return true;  // Server errors
    if (_statusCode === 401) return true;  // Unauthorized (reauth)
    return false;  // Don't retry 2xx, 3xx, or 4xx (except 401)
};
```

📖 **OAuth Pattern**: [copilot-instructions.md § OAuth Token Acquisition Pattern](../copilot-instructions.md#oauth-token-acquisition-pattern)
📖 **SOAP Pattern**: [copilot-instructions.md § SOAP Service Integration Pattern](../copilot-instructions.md#soap-service-integration-pattern)

**OAuth Summary**: x-www-form-urlencoded format, retry interceptor, returns access_token
**SOAP Summary**: Basic auth, manual retry loop (no interceptor), async SOAP client

## Naming Conventions

📖 **Complete Reference**: [copilot-instructions.md § Naming Conventions](../copilot-instructions.md#naming-conventions)

**Quick Summary**:
- Variables/Functions: `camelCase`
- Classes: `PascalCase`
- Environment Variables: `UPPER_SNAKE_CASE`
- Lambda Functions: `ps-igo-{carrier}-{action}`
- Parameter Store: `/ProfService/{carrier}/{function}`

## Logging Best Practices

📖 **Full Details**: [copilot-instructions.md § Logging](../copilot-instructions.md#logging)

**Key Points**:
- Use `util.inspect()` for complex objects (handles circular refs)
- Add `X-iPipeline-Tracking-ID` to metadata for request tracing
- Log levels by environment: DEBUG (sandbox), INFO (qa/uat), WARN/ERROR (prod)
- NEVER log credentials or tokens

## Error Handling

📖 **Full Patterns**: [copilot-instructions.md § Error Handling](../copilot-instructions.md#error-handling)

**Standard Response**: statusCode, headers (with CORS + tracking ID), body (data/err structure)
**SNS Alerts**: Send on 500-level errors with tracking ID and error details

## Load Testing Support

📖 **Details**: [copilot-instructions.md § Load Testing Support](../copilot-instructions.md#load-testing-support)

**Quick Reference**:
- Enabled when: `x-ipipeline-loadtest: true` header + `ALLOW_LOAD_TESTS=true` env var
- Uses mock handlers (pingMockHandler, apiMockHandler) instead of real API calls
- Random delays simulate realistic load patterns

## Adding New Endpoints

📖 **Complete Step-by-Step Guide**: [copilot-instructions.md § Adding New Endpoints](../copilot-instructions.md#adding-new-endpoints---step-by-step-guide)

**Steps Overview**:
1. Update OpenAPI spec (apiSpec.yaml)
2. Create handler (copy template from getWeather.js)
3. Create utility function (follow callAPI.js pattern)
4. Write unit tests (80%+ coverage)
5. Update Terraform module (lambda_props, paramstore_names)
6. Configure all environments (terragrunt.hcl)
7. Create Parameter Store entries (all AWS accounts)
8. Deploy & test (sandbox → qa → uat → prod)

## Quick Reference

📖 **Common Utilities**: [copilot-instructions.md § Common Utilities](../copilot-instructions.md#common-utilities-reference)
📖 **Environment Variables**: [copilot-instructions.md § Environment Variables Reference](../copilot-instructions.md#environment-variables-reference)
📖 **Do's and Don'ts**: [copilot-instructions.md § Dos and Don'ts](../copilot-instructions.md#dos-and-donts)

## Completing Work: PR Workflow

After implementing changes, follow the standard PR workflow:

📖 **Complete Workflow Guide**: [../prompts/agent-pr-workflow.prompt.md](../prompts/agent-pr-workflow.prompt.md)

### Quick Workflow Summary

1. **Validate Changes**
   ```powershell
   cd demo-carrier-api
   npm test  # All tests must pass
   cd ..
   git diff | Select-String -Pattern "(password|secret|key|token)" -Context 2  # No credentials
   ```

2. **Commit Changes**
   ```powershell
   git add .
   git commit -m "feat: add new endpoint for customer data"
   ```

3. **Create/Switch to Feature Branch**
   ```powershell
   git checkout -b feat/JIRA-123-descriptive-name
   ```

4. **Push to Remote**
   ```powershell
   git push -u origin HEAD
   ```

5. **Create Pull Request**
   ```powershell
   gh pr create --repo ipipeline/igo-democarrier-serverless --base dev --title "feat: descriptive title" --web
   ```

**PR Description**: Use [create-github-pull-request-from-specification.prompt.md](../prompts/create-github-pull-request-from-specification.prompt.md) to generate compliant PR descriptions that follow [pull_request_template.md](../pull_request_template.md).

### Development-Specific PR Checklist
- [ ] All utility functions have 80%+ test coverage
- [ ] Handler/utility separation maintained
- [ ] Retry logic implemented correctly
- [ ] Error handling with SNS alerts
- [ ] OAuth token flow working
- [ ] Load testing support (if applicable)
- [ ] **AI-generated code includes attribution comments** (see [javascript.instructions.md § AI Attribution](../instructions/javascript.instructions.md#ai-generated-code-attribution))

## Related Agents
- 🔒 [Security Agent](security-agent.md) - Security validation and compliance
- 🧪 [Testing Agent](testing-agent.md) - Unit test generation
- 🚀 [Infrastructure Agent](infrastructure-agent.md) - Deployment and IaC
- 📝 [Documentation Agent](documentation-agent.md) - API documentation

---

**Version**: 1.1.0
**Last Updated**: December 10, 2025

# Copilot Instructions for iGO Demo Carrier Serverless

## Project Overview

**Repository**: igo-democarrier-serverless  
**Type**: AWS Lambda Serverless REST API  
**Primary Language**: JavaScript (Node.js 22.x)  
**Framework**: AWS Lambda + API Gateway  
**Architecture**: Serverless with Terragrunt/Terraform IaC  
**Purpose**: Demo integration API for iPipeline's iGO Professional Services platform

This is an **AWS Lambda-based serverless API** deployed across multiple environments (sandbox, qa, uat, prod) following iPipeline's iGO platform standards.

> 🤖 **AI Agent Support**: This repository uses specialized AI agents for different development tasks (development, security, testing, infrastructure, documentation). See [AGENTS.md](./AGENTS.md) for details on agent selection and usage.

## Technology Stack

### Runtime & Framework
- **Language**: Node.js 22.x (AWS Lambda runtime)
- **HTTP Client**: axios 1.6.2 (REST), soap 1.0.4 (SOAP)
- **Testing**: Jest 29.7.0 with cross-env
- **Security**: xss-filters 1.2.7
- **Additional**: qs 6.10.3 (query string parsing), mssql 11.0.0 (optional token caching)

### AWS Infrastructure
- **Compute**: AWS Lambda (2 functions: getWeather, getSoap)
- **API**: API Gateway with OpenAPI 3.0 spec + custom Ping authorizer
- **Secrets**: AWS Systems Manager Parameter Store (`/ProfService/{carrier}/{function}`)
- **Logging**: CloudWatch Logs → Splunk (via LogHelperV2)
- **Alerting**: SNS topics (ps-igo-democarrier-api-alerts, ps-igo-democarrier-deploy-alerts)
- **Lambda Layers**: proservices_helper (psHelper, LogHelperV2, securityHelper, snsHelper), ps_nodejs_modules

### Infrastructure as Code
- **Deployment**: Terragrunt 0.x + Terraform 1.1.3-1.9.x
- **Module**: External `igo-ps-aws-lambda-application-module` v1.2.4
- **State Management**: S3 backend with DynamoDB locking
- **Environments**: sandbox, qa, uat, prod (separate AWS accounts)

### CI/CD
- **Platform**: GitHub Actions
- **Workflows**: Shared workflows from `igo-ps-devops/.github/workflows/pull-request-actions.yml@v2`
- **Triggers**: PRs to dev/release/* → auto-deploy to sandbox+qa; merges to main → manual dispatch to uat/prod

## Architecture & Data Flow

### Component Diagram
```
┌─────────────────┐
│  API Gateway    │ ← OpenAPI spec (apiSpec.yaml)
│  (Ping Auth)    │ ← Custom authorizer validates Bearer tokens
└────────┬────────┘
         │
    ┌────▼─────┐
    │  Lambda  │ ← Bare-bones handlers (src/handlers/*.js)
    │ Function │ ← XSS sanitization, lambda warming support
    └────┬─────┘
         │
    ┌────▼─────────┐
    │   Utility    │ ← Business logic (src/utils/call*.js)
    │   Function   │ ← OAuth token acquisition (getToken.js)
    └────┬─────────┘
         │
    ┌────▼──────────┐
    │  External API │ ← REST or SOAP endpoints
    │  (with retry) │ ← Exponential backoff on 401/5xx
    └───────────────┘
```

### Request Flow
1. **API Gateway** receives request → **Ping authorizer** validates Bearer token
2. **Lambda handler** sanitizes input → checks for lambda warming job → calls utility
3. **Utility function** fetches OAuth token from Parameter Store → makes external API call
4. **Retry logic** handles transient failures (401, 5xx) with exponential backoff
5. **Response** sanitized with xss-filters → security headers added → returned to client

### Key Components
- **Handlers** (`src/handlers/*.js`): Minimal entry points, intentionally simple (no unit tests)
- **Utilities** (`src/utils/*.js`): All business logic, comprehensive unit tests (80%+ coverage)
- **Mocks** (`src/mocks/handlers.js`): Load testing support (mock OAuth + API responses)
- **Lambda Layers** (`/opt/nodejs/psUtils`): Shared utilities from `igo-ps-global-lambdas` repo

## Development Guidelines

### Code Organization
```
demo-carrier-api/
├── src/
│   ├── apiSpec.yaml                    # OpenAPI 3.0 spec for API Gateway
│   ├── handlers/                       # Lambda entry points (bare-bones only)
│   │   ├── getWeather.js
│   │   └── getSoap.js
│   ├── utils/                          # Business logic (fully unit tested)
│   │   ├── callAPI.js                  # REST API with OAuth + retry
│   │   ├── callSOAP.js                 # SOAP service integration
│   │   ├── getToken.js                 # OAuth token acquisition
│   │   ├── commonUtils.js              # Shared utilities (shouldRetry, isLoadTest)
│   │   └── tests/                      # Jest unit tests (mirror utils structure)
│   └── mocks/                          # Load testing mocks
│       ├── handlers.js                 # pingMockHandler, apiMockHandler
│       ├── apiMockResponse.json
│       └── tests/
├── postman/                            # Postman collections per environment
├── package.json                        # Dependencies + test script
└── coverage/                           # Jest coverage reports (gitignored)

applied/accounts/{env}/us-east-1/
├── common.tfvars                       # Shared environment variables
├── terragrunt.hcl                      # State backend config + worker role
├── core/
│   └── terragrunt.hcl                  # Core infrastructure (VPC, subnets)
└── demo-carrier-api/
    └── terragrunt.hcl                  # Lambda-specific config + env vars

infrastructure/region/
├── core/
│   └── main.tf                         # Core infrastructure Terraform
└── demo-carrier-api/
    ├── main.tf                         # Lambda module configuration
    ├── variables.tf                    # Input variables
    └── versions.tf                     # Provider version constraints
```

### Naming Conventions

#### Files
- Handlers: `{action}.js` (e.g., `getWeather.js`)
- Utilities: `call{Service}.js` for API calls (e.g., `callAPI.js`, `callSOAP.js`)
- Tests: Mirror source structure in `tests/` subdirectory (e.g., `callAPI.test.js`)
- Mocks: `handlers.js` for mock functions, `{purpose}MockResponse.json` for data

#### Variables & Functions
- **camelCase** for variables and functions: `iPipelineTrackingId`, `getToken`, `shouldRetry`
- **PascalCase** for classes: `LogHelperV2` (from Lambda layer)
- **UPPER_SNAKE_CASE** for environment variables: `LOG_LEVEL_MAPPING`, `RETRYCOUNT`

#### Lambda Functions (Terraform)
- Pattern: `ps-igo-{carrier}-{action}` (e.g., `ps-igo-democarrier-getWeather`)
- SNS Topics: `ps-igo-{carrier}-{purpose}-alerts` (e.g., `ps-igo-democarrier-api-alerts`)
- Parameter Store: `/ProfService/{carrier}/{function}` (e.g., `/ProfService/democarrier/getWeather`)

### Code Style

#### Import Order
1. Node.js built-ins (`util`, `path`)
2. External dependencies (`axios`, `soap`, `xss-filters`)
3. Local utilities (`./getToken`, `./commonUtils`)
4. Mocks (in tests only)
5. Lambda layers last (`/opt/nodejs/psUtils`)

```javascript
// Example from callAPI.js
const { inspect } = require('util');                    // Node.js built-in
const axios = require('axios');                          // External dependency
const { getToken } = require('./getToken');             // Local utility
const { shouldRetry, isLoadTest } = require('./commonUtils');
const { pingMockHandler, apiMockHandler } = require('../mocks/handlers');
const { snsHelper } = require('/opt/nodejs/psUtils');   // Lambda layer
```

#### Logging
- Use `logHelper.info()` for standard flow, `logHelper.error()` for errors
- Use `util.inspect()` for complex objects (handles circular refs, non-JSON)
- Add `iPipelineTrackingId` to metadata for request tracing
- **NEVER** log credentials or tokens (except in DEBUG mode in non-prod)

```javascript
const { inspect } = require('util');
logHelper.addMetaData({iPipelineTrackingId: iPipelineTrackingId});
logHelper.info(`Received: ${inspect(event)}`);
logHelper.error(`Error details: ${inspect(err, { showHidden: true, depth: null })}`);
```

#### Error Handling
- Always use try-catch in handler and utility functions
- Return error objects with `statusCode`, `headers`, `body` structure
- Send SNS alerts for 500-level errors via `snsHelper.sendAlert()`

```javascript
try {
    // Business logic
    return { statusCode: 200, headers: {...}, body: JSON.stringify({ data: result, err: null }) };
} catch (err) {
    logHelper.error(inspect(err, { showHidden: true, depth: null }));
    await snsHelper.sendAlert(message, emailSubject, logHelper);
    return { statusCode: 500, headers: {...}, body: JSON.stringify({ data: null, err: err }) };
}
```

## Common Patterns & Examples

### Lambda Handler Pattern (DO NOT MODIFY STRUCTURE)

Handlers in `src/handlers/*.js` are intentionally **bare-bones wrappers**

### Handler Convention (DO NOT MODIFY)
Handlers in `src/handlers/*.js` are intentionally **bare-bones wrappers**:
```javascript
const { psHelper, LogHelperV2, securityHelper } = require('/opt/nodejs/psUtils');
const apiUtil = require('../utils/callAPI');
const xssFilters = require('xss-filters'); // Import in handler for Checkmarx detection

exports.handler = async (event, context) => {
    let response;
    const logHelper = new LogHelperV2();
    try {
        const safeEvent = JSON.parse(xssFilters.inHTMLData(JSON.stringify(event)));
        if (safeEvent.job === 'lambda-warmer') {
            logHelper.info(safeEvent);
            return 'warmed';
        }
        // Call generic API utility with optional handler-specific configuration
        response = await apiUtil.callApi(safeEvent, psHelper, logHelper, {
            // Optional: urlBuilder function for path parameters
            // Optional: pathParamValidator function for validation
        });
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
**Why:** Keeps handlers untestable-but-simple. All business logic goes in `src/utils/` with comprehensive unit tests.

### Generic callAPI.js Pattern (PREFERRED)

**Use a common `callAPI.js` utility when integrating external REST APIs.** This promotes code reuse and maintainability.

#### Key Principles
1. **Generic utility handles common concerns**: OAuth, retry logic, CORS, error handling, SNS alerts
2. **Handler-specific logic in options**: URL construction, parameter validation
3. **Dynamic Parameter Store paths**: Automatically derived from API endpoint

#### Parameter Store Path Convention

The service name is **automatically extracted from the API endpoint** and used to build the Parameter Store path:

```
Endpoint: /democarrier/v1/getWeather
  → Service name: getWeather
  → Parameter Store: /ProfService/{carrier}/getWeather

Endpoint: /democarrier/v1/getPolicy/{policyNumber}
  → Service name: getPolicy
  → Parameter Store: /ProfService/{carrier}/getPolicy
```

**Implementation:**
```javascript
// commonUtils.js - Extract service name from resource path
exports.getServiceNameFromResource = (resource) => {
    if (!resource || typeof resource !== 'string') return '';
    const [path] = resource.split('?'); // Drop query params
    const normalized = path.replace(/\/+$/, ''); // Remove trailing slashes
    const segments = normalized.split('/');
    let name = segments.pop() ?? ''; // Last segment is service name
    return name.replace(/\s+/g, '').trim(); // Strip spaces
};

// callAPI.js - Dynamically build Parameter Store path
const resource = getResource(event); // event.resource or event.path
const serviceName = getServiceNameFromResource(resource);
const psParams = await psHelper.getStoredParameterJson(
    `/ProfService/{carrier}/${serviceName}`, 
    logHelper
);
```

#### When to Use Generic callAPI.js

✅ **DO use callAPI.js when:**
- Making REST API calls with OAuth 2.0 client credentials flow
- External API requires retry logic and error handling
- Multiple endpoints share similar patterns (OAuth, CORS, logging, alerts)
- API responses are JSON-based

❌ **DO NOT use callAPI.js when:**
- Making SOAP API calls (use `callSOAP.js` instead)
- API requires custom authentication (non-OAuth)
- Integration pattern is fundamentally different
- Complexity of options makes code harder to understand than a separate utility

#### Handler-Specific Configuration

Pass handler-specific logic as options to keep handlers clean:

**Simple endpoint (no path parameters):**
```javascript
// getWeather.js - No configuration needed
response = await apiUtil.callApi(safeEvent, psHelper, logHelper, {});
```

**Endpoint with path parameters:**
```javascript
// getPolicy.js - Add URL builder and validator
const validatePolicyNumber = (event, logHelper, origin, iPipelineTrackingId) => {
    const policyNumber = event.pathParameters?.policyNumber;
    if (!policyNumber) {
        logHelper.error('Missing required path parameter: policyNumber');
        return { // Return error response
            statusCode: 400,
            headers: { /* ... */ },
            body: JSON.stringify({ data: null, err: 'Missing required parameter: policyNumber' })
        };
    }
    logHelper.info(`Getting policy for policyNumber: ${policyNumber}`);
    return null; // Validation passed
};

const buildPolicyUrl = (endpoint, event) => {
    const policyNumber = event.pathParameters.policyNumber;
    return `${endpoint}/${policyNumber}`;
};

response = await apiUtil.callApi(safeEvent, psHelper, logHelper, {
    urlBuilder: buildPolicyUrl,
    pathParamValidator: validatePolicyNumber
});
```

#### Benefits of This Pattern

1. **Code Reuse**: Common concerns (OAuth, retry, CORS, logging) implemented once
2. **Maintainability**: Bug fixes and enhancements apply to all endpoints
3. **Consistency**: All REST API integrations follow the same pattern
4. **Convention over Configuration**: Service names automatically derived from endpoints
5. **Flexibility**: Handler-specific logic passed as options without modifying generic utility
6. **Testability**: Generic utility has comprehensive unit tests; handlers stay simple

#### Adding New REST API Endpoints

1. Create handler in `src/handlers/{serviceName}.js`
2. Call generic `callAPI.js` with options (if needed)
3. Add validation and URL builder functions in handler (if path parameters required)
4. Create Parameter Store entry at `/ProfService/{carrier}/{serviceName}`
5. Add endpoint to `apiSpec.yaml`
6. Update Terraform configuration

**No need to create separate utility files like `callPolicyAPI.js` - use the generic callAPI.js instead!**

### Generic callAPI.js Implementation Pattern

**Current implementation in `src/utils/callAPI.js`** - Use as reference for REST API integrations:

```javascript
const { inspect } = require('util');
const axios = require('axios');
const { getToken } = require('./getToken');
const { shouldRetry, isLoadTest, getResource, getServiceNameFromResource } = require('./commonUtils');
const { pingMockHandler, apiMockHandler } = require('../mocks/handlers');
const { snsHelper } = require('/opt/nodejs/psUtils');

/**
 * Generic API call function with OAuth authentication and retry logic
 * @param {Object} event - Lambda event object
 * @param {Object} psHelper - Parameter Store helper
 * @param {Object} logHelper - Logging helper
 * @param {Object} options - Configuration options
 * @param {Function} [options.urlBuilder] - Optional URL builder (receives endpoint, event, psParams)
 * @param {Function} [options.pathParamValidator] - Optional validator (receives event, logHelper, origin, iPipelineTrackingId)
 */
exports.callApi = async (event, psHelper, logHelper, options = {}) => {
	const headers = event.headers ? event.headers : {};
    let allowedOriginStr = process.env.ALLOWED_ORIGIN_LIST;
    let allowedOriginList = allowedOriginStr.split(',');

    const iPipelineTrackingId = headers['X-iPipeline-Tracking-ID'];
    logHelper.addMetaData({iPipelineTrackingId: iPipelineTrackingId});
    logHelper.info(`X-iPipeline-Tracking-ID: ${iPipelineTrackingId}`);

    let origin;
    if ('Origin' in headers) {
		logHelper.info(`Received Origin header: ${headers.Origin}`);
        if (allowedOriginList.includes(headers.Origin)) {
            logHelper.info('Origin is Included');
            origin = headers.Origin;
        }
    } else {
        logHelper.info('No Origin header received');
    }

    try {
        logHelper.info(`Received: ${inspect(event)}`);
        
        // Extract service name from endpoint path for dynamic Parameter Store lookup
        const resource = getResource(event); // event.resource or event.path
        const serviceName = getServiceNameFromResource(resource); // e.g., "getWeather", "getPolicy"
        logHelper.info(`Service Name: ${serviceName}`);
        
        // Run path parameter validation if provided
        if (options.pathParamValidator) {
            const validationResult = options.pathParamValidator(event, logHelper, origin, iPipelineTrackingId);
            if (validationResult) {
                return validationResult; // Return error response if validation fails
            }
        }
        
        logHelper.info('Calling to get oAuth token');

        // Dynamically build Parameter Store path using service name
        // Pattern: /ProfService/{carrier}/{serviceName}
        const psParams = await psHelper.getStoredParameterJson(
            `/ProfService/{carrier}/${serviceName}`,
            logHelper
        );

        const oAuthItems = {
            'client_id': psParams.credentials.client_id,
            'client_secret': psParams.credentials.client_secret,
            'endpoint': psParams.credentials.endpoint
        }
        
        let token;
        if (isLoadTest(headers)) {
            token = await pingMockHandler(logHelper);
        } else {
            token = await getToken(oAuthItems, logHelper);
        }

        // logHelper.info(`Token: ${token}`);
        // Non-sensitive items, like endpoints and retrycount, can be set in environment variables defined in the Infrastructure as Code.
        // Environment variables are stored in the process.env object.
        const environmentVars = process.env;
        logHelper.info(`Environment: ${inspect(environmentVars)}`);
        const endpoint = psParams.endpoint;
        logHelper.info(`Endpoint: ${endpoint}`);
        const retryCount = environmentVars.RETRYCOUNT;

        const url = endpoint;

        if (token.includes('Error')) {
            //logHelper.error(`Error when calling for token: ${token}`);
            //throw the error, catch() below will handle, log, etc.
            throw token;
        }

        // Creating header object used by axios for adding HTTP Header items.
        let _header = {};
        _header['authorization'] = `Bearer ${token}`; //create a header for the token.

        // There could be other instances of axios used in other JS files, so better to create a separate instance.
        // This way everything done here is isolated to only this instance and doesn't accidentally bleed over to other instances.
        let instance = axios.create({
            headers: _header,
            retry: retryCount,
            timeout: environmentVars.TIMEOUT
        });

        // Setting up an interceptor gives us the ability to handle the requests or responses before handled by 'try' or 'catch'.
        // This lets us do things like logging details about the response or handling retry logic.
        // https://axios-http.com/docs/interceptors
        /* istanbul ignore next */
        instance.interceptors.response.use(
            function(response) {
                // Any status code that are within the range of 2xx cause this function to trigger.
                logHelper.info(
                    `method=${response.config.method}
                         mappedServiceUrl=${response.config.url}
                         responseStatusCode=${response.status}`
                );
                return response;
            },
            async function axiosRetryInterceptor (error) {
                let config = error.config;
                let errorMsg = {
                    StatusCode: 0,
                    Details: ''
                };
                // Any status codes that falls outside the range of 2xx causes this function to trigger.
                if (error.response) {
                    // The request was made and the server responded with a status code
                    // that falls out of the range of 2xx
                    errorMsg.StatusCode = error.response.status;
                    errorMsg.Details = inspect(error.response.data);
                } else if (error.message) {
                    // Something happened in setting up the request that triggered an Error
                    errorMsg.Details = inspect(error.message);
                } else {
                    // The request was made but no response was received
                    // http.ClientRequest in node.js
                    errorMsg.Details = inspect(error);
                }

                //Check if the status code is a value that we shouldn't bother retrying.
                if (error.response && !shouldRetry(error.response.status)) {
                    return Promise.reject(errorMsg);
                }

                // If the retrycount is greater than defined amount, stop trying.
                config.__retryCount = config.__retryCount || 1;
                if (config.__retryCount >= retryCount) {
                    return Promise.reject(errorMsg);
                }
                config.__retryCount += 1;

                //log the error since we are retrying
                logHelper.error(inspect(errorMsg));

                // Setting a function to wait on to act as a delay before retrying. Currently set to 1ms plus time for next event cycle.
                const backoff = new Promise(function(resolve) {
                    setTimeout(function() {
                        resolve();
                    }, 100);
                });
                await backoff;
                logHelper.info(`Calling API - ${config.__retryCount} of ${retryCount}`);
                // This will rerun the next request.
                return instance(config);
            }
        );

        logHelper.info(`Calling API - 1 of ${retryCount}`);
        let response;
        if (isLoadTest(headers)) {
            response = await apiMockHandler(logHelper);
        } else {
            response = await instance.get(url);
        }

        // This will log PII data if INFO is turned on in prod and response contains PII data.
        // So ensure the log level is never set to INFO, or proper steps are made to mask any sensitive data.
        logHelper.info(`Response: ${inspect(response.data, { showHidden: true, depth: null })}`);

        return {
            'statusCode': 200,
            headers:{
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': origin, // Required for CORS support to work
                'Access-Control-Allow-Methods' : '*',
                'X-iPipeline-Tracking-ID': iPipelineTrackingId
            },
            'body': JSON.stringify({
                data: response.data,
                err: null
            })
        };
    } catch (err) {
        logHelper.error(inspect(err, { showHidden: true, depth: null }));

        //For this Alert to work, you need a SNS Topic setup and email subscriptions (var.alert_emails)
        let emailSubject = 'Demo Carrier API notification - DO NOT REPLY';
        let message = `An error has occurred in the Demo Carrier API: ${headers.Host}${event.resource}\niPipelineTrackingId: ${iPipelineTrackingId}\n\n`;
        message += `Error details: ${inspect(err)} \n\n`;
        message += `This notification is being sent to you as part of an iPipeline Demo Carrier distribution list.\nIf you wish to stop receiving notifications, please contact the iPipeline Support team. \n\n\n\n\n`;
        const alertResp = await snsHelper.sendAlert(message, emailSubject, logHelper);

        return {
            'statusCode': 500,
            headers:{
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': origin, // Required for CORS support to work
                'Access-Control-Allow-Methods' : '*',
                'X-iPipeline-Tracking-ID': iPipelineTrackingId
            },
            'body': JSON.stringify({
                data: null,
                err: err
            })
        };
    }
};
```

### OAuth Token Acquisition Pattern

```javascript
const { inspect } = require('util');
const qs = require('qs');
const axios = require('axios');
const { shouldRetry } = require('./commonUtils');

exports.getToken = async (oAuthItems, logHelper) => {
    try {
        const endpoint = oAuthItems.endpoint;
        const retryCount = process.env.RETRYCOUNT;
        
        // PING requires x-www-form-urlencoded format
        const data = qs.stringify({
            'grant_type': 'client_credentials',
            'scope': 'iGO.ViewForms.API',
            'client_secret': oAuthItems.client_secret,
            'client_id': oAuthItems.client_id,
            'gaid': '7708'
        });
        
        let tokenInstance = axios.create({
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            retry: retryCount,
            timeout: process.env.TIMEOUT
        });
        
        // Add retry interceptor (similar pattern to API calls)
        tokenInstance.interceptors.response.use(/* ... */);
        
        const response = await tokenInstance.post(endpoint, data);
        return response.data.access_token;
        
    } catch (err) {
        logHelper.error(`Error in getToken(): ${inspect(err, { showHidden: true, depth: null })}`);
        return `Error: ${inspect(err, { showHidden: true, depth: null })}`;
    }
};
```

### SOAP Service Integration Pattern

```javascript
const soap = require('soap');
const { shouldRetry, isLoadTest } = require('./commonUtils');

exports.callSoap = async (event, psHelper, logHelper) => {
    try {
        const psParams = await psHelper.getStoredParameterJson('/ProfService/democarrier/getSoap', logHelper);
        const endpoint = psParams.endpoint;
        const retryCount = process.env.RETRYCOUNT;
        
        // Basic auth for SOAP
        const username = isLoadTest(headers) ? "testuser" : psParams.credentials.username;
        const password = isLoadTest(headers) ? "xxxxxxxx" : psParams.credentials.password;
        
        const auth = 'Basic ' + Buffer.from(`${username}:${password}`).toString('base64');
        const options = {
            wsdl_headers: { 'Authorization': auth }
        };
        
        // Create SOAP client
        const client = await soap.createClientAsync(endpoint, options);
        client.setSecurity(new soap.BasicAuthSecurity(username, password));
        
        const request = event.body ? JSON.parse(event.body) : {};
        
        // Manual retry loop for SOAP (no interceptor support)
        let response;
        let counter = 1;
        while (counter <= retryCount) {
            try {
                response = await client.NumberToWordsAsync(request, { timeout: process.env.TIMEOUT });
                break;
            } catch (err) {
                if (counter == retryCount) {
                    return handleErrorMessage(err, origin, iPipelineTrackingId);
                }
                logHelper.error(inspect(err, { showHidden: true, depth: null }));
            }
            counter++;
        }
        
        return {
            statusCode: 200,
            headers: { /* ... */ },
            body: JSON.stringify({ data: response, err: null })
        };
    } catch (err) {
        return handleErrorMessage(err, origin, iPipelineTrackingId);
    }
};
```

### Common Utilities Pattern

**Critical helper functions** in `src/utils/commonUtils.js`:

```javascript
// Determine if HTTP status code should trigger retry
exports.shouldRetry = (_statusCode) => {
    if (_statusCode >= 500) return true;  // Server errors
    if (_statusCode === 401) return true;  // Unauthorized (reauth)
    return false;  // Don't retry 2xx, 3xx, or 4xx (except 401)
};

// Check if request is a load test (mock responses)
exports.isLoadTest = (_headers = {}) => {
    return ('x-ipipeline-loadtest' in _headers && 
            _headers['x-ipipeline-loadtest'] === 'true') && 
            process.env.ALLOW_LOAD_TESTS === 'true';
};

// Extract resource path from event (supports both event.resource and event.path)
exports.getResource = (event) => {
    if (event.resource) {
        return event.resource; 
    }
    return event.path;
};

// Extract service name from resource path for dynamic Parameter Store lookup
// Examples: 
//   "/democarrier/v1/getWeather" → "getWeather"
//   "/democarrier/v1/getPolicy/{policyNumber}" → "getPolicy"
exports.getServiceNameFromResource = (resource) => {
    if (!resource || typeof resource !== 'string') {
        return '';
    }
    
    // Drop query parameters
    const [path] = resource.split('?');
    
    // Remove trailing slashes
    const normalized = path.replace(/\/+$/, '');
    
    // Return the last segment of the path
    const segments = normalized.split('/');
    let name = segments.pop() ?? '';
    
    // Strip any spaces and trim
    return name.replace(/\s+/g, '').trim();
};

// ⚠️ CRITICAL: Reusable axios retry interceptor - USE THIS FOR ALL AXIOS INSTANCES
// Adds standardized retry logic with exponential backoff to any axios instance
exports.addRetryInterceptor = (instance, retryCount, logHelper) => {
    instance.interceptors.response.use(
        function(response) {
            // Success: 2xx status codes
            logHelper.info(
                `method=${response.config.method} 
                 mappedServiceUrl=${response.config.url} 
                 responseStatusCode=${response.status}`
            );
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
            
            // Don't retry on non-retryable status codes
            if (error.response && !exports.shouldRetry(error.response.status)) {
                return Promise.reject(errorMsg);
            }
            
            // Check retry count
            config.__retryCount = config.__retryCount || 1;
            if (config.__retryCount >= retryCount) {
                return Promise.reject(errorMsg);
            }
            config.__retryCount += 1;
            
            logHelper.error(inspect(errorMsg));
            
            // Exponential backoff: 100ms * retry count
            const backoff = new Promise(function(resolve) {
                setTimeout(function() {
                    resolve();
                }, 100 * config.__retryCount);
            });
            await backoff;
            
            logHelper.info(`Retry attempt ${config.__retryCount} of ${retryCount}`);
            return instance(config);
        }
    );
    
    return instance;
};
```

### Axios Retry Interceptor Pattern - REUSABLE FUNCTION ⚠️ CRITICAL

**USE `addRetryInterceptor` from `commonUtils.js` for ALL axios instances!**

This pattern ensures consistent retry behavior, exponential backoff, and proper error handling across all API calls.

#### ✅ Correct Usage (Reusable Function)

```javascript
const { addRetryInterceptor } = require('./commonUtils');

// Create axios instance
const instance = axios.create({
    headers: { 'Authorization': `Bearer ${token}` },
    timeout: process.env.TIMEOUT
});

// Add retry interceptor using reusable function
addRetryInterceptor(instance, retryCount, logHelper);

// Make API call
const response = await instance.get(url);
```

#### ❌ Wrong Usage (Inline Interceptor - DO NOT DO THIS)

```javascript
// DON'T duplicate interceptor logic inline!
instance.interceptors.response.use(
    function(response) {
        logHelper.info(`status=${response.status}`);
        return response;
    },
    async function(error) {
        // Custom retry logic here - AVOID THIS!
    }
);
```

#### Function Signature

```javascript
/**
 * Adds retry interceptor with exponential backoff to axios instance
 * @param {Object} instance - Axios instance
 * @param {Number} retryCount - Maximum number of retry attempts
 * @param {Object} logHelper - Logging helper instance
 * @returns {Object} Modified axios instance
 */
exports.addRetryInterceptor = (instance, retryCount, logHelper)
```

#### Implementation Details

**The reusable interceptor pattern** in `commonUtils.js`:
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
        if (config.__retryCount >= retryCount) {
            return Promise.reject(errorMsg);
        }
        config.__retryCount += 1;
        
        logHelper.error(inspect(errorMsg));
        
        // Exponential backoff: 100ms delay
        const backoff = new Promise(resolve => setTimeout(resolve, 100));
        await backoff;
        
        logHelper.info(`Calling API - ${config.__retryCount} of ${retryCount}`);
        return instance(config);
    }
);
```

## Security Guidelines

### Mandatory Security Requirements
1. **XSS Sanitization**: Use `xss-filters.inHTMLData()` on ALL inputs/outputs
   - Import in **handler** (not helper) for Checkmarx scan detection
   - Sanitize event on entry: `JSON.parse(xssFilters.inHTMLData(JSON.stringify(event)))`
   - Sanitize response on exit: `JSON.parse(xssFilters.inHTMLData(JSON.stringify(response)))`

2. **Parameter Store**: Credentials ONLY in AWS Parameter Store
   - Pattern: `/ProfService/{carrier}/{function}`
   - Example: `/ProfService/democarrier/getWeather`
   - Structure:
     ```json
     {
       "credentials": {
         "client_id": "...",
         "client_secret": "...",
         "endpoint": "https://auth-endpoint.com"
       },
       "endpoint": "https://api-endpoint.com"
     }
     ```

3. **Security Headers**: Always apply via `securityHelper.getSecurityHeaders()`
   - Includes: Content Security Policy, X-Content-Type-Options, X-Frame-Options, Strict-Transport-Security

4. **CORS**: Validate origins against allowlist
   ```javascript
   let allowedOriginList = process.env.ALLOWED_ORIGIN_LIST.split(',');
   let origin;
   if ('Origin' in headers && allowedOriginList.includes(headers.Origin)) {
       origin = headers.Origin;
   }
   ```

5. **Logging**: NEVER log credentials or PII
   - Use DEBUG level only in non-prod for sensitive data
   - Use `util.inspect()` instead of `JSON.stringify()` for error objects

### Load Testing Support

When header `x-ipipeline-loadtest: true` AND `ALLOW_LOAD_TESTS=true`:
```javascript
const { isLoadTest } = require('./commonUtils');

if (isLoadTest(headers)) {
    token = await pingMockHandler(logHelper);  // Mock OAuth token
    response = await apiMockHandler(logHelper);  // Mock API response
}
```

Mock handlers (`src/mocks/handlers.js`) introduce random delays:
- 10% chance: 1000ms delay
- 22% chance: 500ms delay
- 68% chance: 100ms delay
- 1% chance: throw error

## Testing Requirements

### Running Tests
```powershell
cd demo-carrier-api
npm test  # Runs Jest 29.7.0 with coverage reporting
```

### Test Organization
```
src/utils/
├── callAPI.js
├── callSOAP.js
├── getToken.js
├── commonUtils.js
└── tests/
    ├── callAPI.test.js         # Mirrors callAPI.js
    ├── callSOAP.test.js        # Mirrors callSOAP.js
    ├── getToken.test.js        # Mirrors getToken.js
    └── commonUtils.test.js     # Mirrors commonUtils.js
```

**Coverage Requirements:**
- Handlers: NOT unit tested (intentionally simple, validated in AWS sandbox)
- Utils: 80%+ coverage required
- All utility functions must have comprehensive unit tests

### Testing Patterns

#### Mocking Lambda Layers
Lambda layers from `/opt/nodejs/psUtils` don't exist locally, so mock them:
```javascript
jest.mock('/opt/nodejs/psUtils', () => ({
    psHelper: {
        getStoredParameterJson: jest.fn().mockResolvedValue({
            credentials: {
                client_id: 'test_id',
                client_secret: 'test_secret',
                endpoint: 'https://auth.example.com'
            },
            endpoint: 'https://api.example.com'
        })
    },
    LogHelperV2: class MockLogHelper {
        info(msg) { console.info(msg); }
        error(msg) { console.error(msg); }
        addMetaData(data) { return true; }
    },
    securityHelper: {
        getSecurityHeaders: jest.fn().mockReturnValue({
            'Content-Security-Policy': "default-src 'self'",
            'X-Content-Type-Options': 'nosniff'
        })
    },
    snsHelper: {
        sendAlert: jest.fn().mockResolvedValue(true)
    }
}), { virtual: true });
```

#### Mocking Axios with Interceptors
**Critical pattern** for testing API calls with retry logic:
```javascript
const axios = require('axios');
jest.mock('axios');

// Mock axios.create to return axios itself
axios.create.mockImplementation((config) => axios);

// Mock interceptors (no-op in tests)
axios.interceptors = {
    response: {
        use: jest.fn().mockImplementation((successFn, errorFn) => {
            // Optionally test interceptor logic here
            return;
        })
    }
};

// Mock successful GET request
axios.get.mockResolvedValueOnce({
    data: { approverID: '12345', pin: '9876', status: 'active' }
});

// Mock failed request
axios.get.mockRejectedValueOnce(new Error('Network error'));
```

#### Mocking getToken Module
```javascript
const getToken = require('../getToken');
jest.mock('../getToken');

// Mock successful token retrieval
getToken.getToken.mockResolvedValue('mock_token_12345');

// Mock token error
getToken.getToken.mockResolvedValue('Error: Token acquisition failed');
```

#### Test Structure Example
```javascript
describe('callAPI should', () => {
    const OLD_ENV = process.env;
    
    beforeEach(() => {
        jest.clearAllMocks();
        process.env = { ...OLD_ENV };
        process.env.RETRYCOUNT = '3';
        process.env.TIMEOUT = '3000';
        process.env.ALLOWED_ORIGIN_LIST = 'http://localhost,https://local.ipipeline.com';
    });
    
    afterAll(() => {
        jest.resetAllMocks();
        process.env = OLD_ENV;
    });
    
    test('returns 200 with valid approverID', async () => {
        // Arrange
        const event = {
            pathParameters: { approverID: '12345' },
            headers: { 'X-iPipeline-Tracking-ID': 'test-123' }
        };
        
        axios.create.mockImplementation((config) => axios);
        axios.interceptors.response.use.mockImplementation(() => {});
        axios.get.mockResolvedValueOnce({ data: { pin: '9876' } });
        getToken.getToken.mockResolvedValue('mock_token');
        
        // Act
        let resp = await callAPI.callAPI(event, mockPsHelper, mockLogHelper);
        
        // Assert
        expect(resp.statusCode).toBe(200);
        expect(resp.body).toContain('9876');
    });
    
    test('returns 400 when approverID missing', async () => {
        const event = { pathParameters: {} };
        let resp = await callAPI.callAPI(event, mockPsHelper, mockLogHelper);
        
        expect(resp.statusCode).toBe(400);
        expect(resp.body).toContain('Missing required parameter: approverID');
    });
    
    test('returns 500 on API error', async () => {
        const event = {
            pathParameters: { approverID: '12345' },
            headers: { 'X-iPipeline-Tracking-ID': 'test-123' }
        };
        
        axios.create.mockImplementation((config) => axios);
        axios.get.mockRejectedValueOnce(new Error('API down'));
        getToken.getToken.mockResolvedValue('mock_token');
        
        let resp = await callAPI.callAPI(event, mockPsHelper, mockLogHelper);
        
        expect(resp.statusCode).toBe(500);
    });
});
```

### Test Coverage Location
Coverage reports generated in `demo-carrier-api/coverage/`:
- `lcov-report/index.html` - HTML coverage report
- `coverage-final.json` - JSON coverage data
- Gitignored (not committed to repo)

## Dependencies & Tools

### Approved Dependencies
**Production** (`package.json` dependencies):
- `xss-filters` ^1.2.7 - XSS sanitization (required for Checkmarx compliance)

**Development** (`package.json` devDependencies):
- `axios` ^1.6.2 - HTTP client for REST APIs
- `soap` ^1.0.4 - SOAP client for legacy integrations
- `qs` ^6.10.3 - Query string parsing (OAuth token requests)
- `mssql` ^11.0.0 - Optional SQL Server client (token caching)
- `jest` ^29.7.0 - Testing framework
- `cross-env` ^7.0.3 - Cross-platform environment variables

**Lambda Layers** (provided at runtime, do NOT add to package.json):
- `/opt/nodejs/psUtils` - psHelper, LogHelperV2, securityHelper, snsHelper
  - Source: `igo-ps-global-lambdas` repository
  - Managed by PS iGO team

### Version Constraints
- **Node.js**: 22.x (AWS Lambda runtime)
- **Jest**: 29.x (use cross-env for NODE_OPTIONS)
- **Terraform**: 1.1.3 - 1.9.x
- **Terragrunt**: 0.x

### Dependency Management Strategy
**When to update `igo-ps-global-lambdas` vs local `package.json`:**
- **Lambda Layer** (update `igo-ps-global-lambdas`): Shared utilities, common dependencies used by multiple projects
- **Local package.json** (update this repo): Project-specific dependencies, utilities unique to demo-carrier

## Infrastructure & Deployment

### Directory Structure
```
applied/accounts/{env}/us-east-1/
├── common.tfvars         # Shared environment config (tags, account ID, region)
├── terragrunt.hcl        # S3 backend, DynamoDB lock, worker role ARN
├── core/
│   └── terragrunt.hcl    # VPC, subnets, security groups
└── demo-carrier-api/
    └── terragrunt.hcl    # Lambda configs, env vars, SNS alert emails

infrastructure/region/
├── core/
│   ├── main.tf           # Core infrastructure (networking)
│   ├── variables.tf
│   └── versions.tf
└── demo-carrier-api/
    ├── main.tf           # Lambda module configuration
    ├── variables.tf      # Input variables
    ├── versions.tf       # Provider version constraints
    └── README.md         # API documentation
```

### Terragrunt Configuration Pattern

**State Management** (`applied/accounts/{env}/us-east-1/terragrunt.hcl`):
```hcl
remote_state {
  backend = "s3"
  config = {
    bucket         = "us-east-1-{account_id}-democarrier-savedstate"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock-table"
    role_arn       = "arn:aws:iam::{account_id}:role/democarrier-worker-role"
  }
}
```

**Lambda Configuration** (`applied/accounts/{env}/us-east-1/demo-carrier-api/terragrunt.hcl`):
```hcl
terraform {
  source = "../../../../..//infrastructure/region/demo-carrier-api/"
}

include {
  path = find_in_parent_folders()
}

inputs = {
    api_stage_name = "api"

    environment_vars_getWeather = {
        AWS                 = true
        LOG_LEVEL_MAPPING   = "INFO"      # DEBUG in sandbox, INFO+ in prod
        RETRYCOUNT          = 3           # Number of retry attempts
        TIMEOUT             = 3000        # Request timeout (milliseconds)
        ALLOW_LOAD_TESTS    = true        # Enable mock handlers
        LAMBDA_WARMER       = true        # Keep Lambda warm
        ALLOWED_ORIGIN_LIST = "http://localhost,https://local.ipipeline.com"
    }
    
    # SNS alert configuration
    alert_emails = ["team@ipipeline.com"]
    deploy_emails = ["deployments@ipipeline.com"]
}
```

### Deployment Workflow

#### Local Deployment (Manual)
```powershell
# Navigate to specific environment
cd applied/accounts/sandbox/us-east-1/demo-carrier-api

# Preview changes
terragrunt plan

# Apply changes (requires approval)
terragrunt apply

# Destroy infrastructure (DANGER - use with caution)
terragrunt destroy
```

#### CI/CD Deployment (Automated)
**GitHub Actions** workflows in `.github/workflows/`:

1. **Pull Request to dev/release/\*** (`pull_request_dev_actions.yml`):
   - Trigger: PR opened, synchronized, or reopened
   - Actions: Linting, Jest tests, Terragrunt plan
   - Auto-deploy: Sandbox + QA environments
   - Concurrency: Single workflow at a time (prevents state lock conflicts)

2. **Merge to main** (`pr_merge_main_actions.yml`):
   - Trigger: PR merged to main branch
   - Actions: Terragrunt plan for UAT/PROD
   - Deployment: Manual dispatch required (security gate)

3. **Scheduled Deployments** (`schedule_deploy.yml`, `schedule_deploy_prod.yml`):
   - Automated deployments on schedule (if configured)

**Workflow Configuration:**
```yaml
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

### Environment Variables Reference
| Variable | Values | Description |
|----------|--------|-------------|
| `AWS` | true/false | Enable AWS-specific features |
| `LOG_LEVEL_MAPPING` | DEBUG/INFO/WARN/ERROR | Logging verbosity |
| `RETRYCOUNT` | 1-5 | Number of API retry attempts |
| `TIMEOUT` | milliseconds | Request timeout (default: 3000) |
| `ALLOW_LOAD_TESTS` | true/false | Enable mock handlers for load testing |
| `LAMBDA_WARMER` | true/false | Enable Lambda warming to reduce cold starts |
| `ALLOWED_ORIGIN_LIST` | CSV string | CORS allowed origins |

### Lambda Layer Management
Layers defined in `infrastructure/region/demo-carrier-api/main.tf`:
```hcl
data "aws_lambda_layer_version" "proservices_helper_version" {
  layer_name = "proservices_helper"  # psHelper, LogHelperV2, securityHelper, snsHelper
}

data "aws_lambda_layer_version" "ps_nodejs_modules_version" {
  layer_name = "ps_nodejs_modules"   # Common npm dependencies
}

lambda_props = [
  {
    function_name = "ps-igo-democarrier-getWeather"
    layers = [
      data.aws_lambda_layer_version.proservices_helper_version.arn,
      data.aws_lambda_layer_version.ps_nodejs_modules_version.arn
    ]
    # ... other configuration
  }
]
```

**Layer Update Process:**
1. Update layer code in `igo-ps-global-lambdas` repository
2. Publish new layer version to AWS
3. Lambda functions automatically use latest version (data source queries latest)

## Adding New Endpoints - Step-by-Step Guide

### 1. Update OpenAPI Spec
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

### 2. Create Handler
**File**: `demo-carrier-api/src/handlers/newEndpoint.js`

Copy from `getWeather.js` template - change only:
- Module docstring
- Import path: `require('../utils/callNewAPI')`
- Function call: `apiUtil.callNewApi(safeEvent, psHelper, logHelper)`

### 3. Create Utility Function
**File**: `demo-carrier-api/src/utils/callNewAPI.js`

Follow pattern from `callAPI.js`:
- Import required modules (util, axios, getToken, commonUtils, mocks, snsHelper)
- **⚠️ CRITICAL**: Import `addRetryInterceptor` from `commonUtils`
- Export async function: `exports.callNewApi = async (event, psHelper, logHelper) => {}`
- Implement: Parameter Store fetch, OAuth token, **USE addRetryInterceptor()**, error handling
- Return: Consistent response structure with statusCode, headers, body

**Required import:**
```javascript
const { shouldRetry, isLoadTest, addRetryInterceptor } = require('./commonUtils');
```

**After creating axios instance:**
```javascript
const instance = axios.create({ /* config */ });
addRetryInterceptor(instance, retryCount, logHelper);  // ⚠️ REQUIRED
```

### 4. Write Unit Tests
**File**: `demo-carrier-api/src/utils/tests/callNewAPI.test.js`

Follow pattern from `callAPI.test.js`:
```javascript
jest.mock('axios');
jest.mock('../getToken');
jest.mock('/opt/nodejs/psUtils', () => ({ /* mock layer */ }), { virtual: true });

describe('callNewAPI should', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        process.env.RETRYCOUNT = '3';
        process.env.TIMEOUT = '3000';
        process.env.ALLOWED_ORIGIN_LIST = 'http://localhost';
    });
    
    test('returns 200 on success', async () => { /* ... */ });
    test('returns 400 on invalid input', async () => { /* ... */ });
    test('returns 500 on error', async () => { /* ... */ });
});
```

Run tests: `cd demo-carrier-api && npm test`

### 5. Update Terraform Module
**File**: `infrastructure/region/demo-carrier-api/main.tf`

Add to `lambda_props` array:
```hcl
{
  "function_name"                  = "ps-igo-democarrier-newEndpoint"
  "lambda_description"             = "Demo Carrier API - Your Description"
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

**File**: `infrastructure/region/demo-carrier-api/variables.tf`

Add variable declaration:
```hcl
variable "environment_vars_newEndpoint" {
  type        = map(string)
  description = "Environment variables for newEndpoint Lambda"
}
```

### 6. Configure All Environments
Update **each** environment's terragrunt.hcl:
- `applied/accounts/sandbox/us-east-1/demo-carrier-api/terragrunt.hcl`
- `applied/accounts/qa/us-east-1/demo-carrier-api/terragrunt.hcl`
- `applied/accounts/uat/us-east-1/demo-carrier-api/terragrunt.hcl`
- `applied/accounts/prod/us-east-1/demo-carrier-api/terragrunt.hcl`

Add to `inputs`:
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

### 7. Create Parameter Store Entries
For **each** AWS account (sandbox, qa, uat, prod):

**AWS Console** → Systems Manager → Parameter Store → Create parameter:
- Name: `/ProfService/democarrier/newEndpoint`
- Type: SecureString
- Value:
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

### 8. Deploy & Test
```powershell
# Test locally
cd demo-carrier-api
npm test

# Deploy to sandbox (auto-deploys on PR to dev)
git checkout -b feat/new-endpoint
git add .
git commit -m "feat: add newEndpoint API integration"
git push origin feat/new-endpoint
# Create PR to dev branch

# After sandbox validation, merge to dev
# Then deploy to QA (auto-deploy)
# Then deploy to UAT/PROD (manual dispatch)
```

### 9. Update Postman Collection
**File**: `demo-carrier-api/postman/demo_carrier_collection.postman_collection.json`

Add new request following existing pattern with environment variables.

## Monitoring & Debugging

**CloudWatch Logs:**
- Log groups: `/aws/lambda/ps-igo-democarrier-{functionName}`
- Use `X-iPipeline-Tracking-ID` header to trace requests across services

**Splunk Queries:**
- QA: `index=igo_aws_webservice_qa source=*democarrier*`
- UAT: `index=igo_aws_webservice_uat source=*democarrier*`
- PROD: `index=igo_aws_webservice_prod source=*democarrier*`

**SNS Alerts:**
- Topic: `ps-igo-democarrier-api-alerts`
- Sent on Lambda errors, external API failures, auth failures
- Configure recipients in `alert_emails` (terragrunt.hcl)

**Postman Testing:**
- Collections in `demo-carrier-api/postman/` for each environment
- Include auth token acquisition and full test scenarios

## Dos and Don'ts

### Do ✅
- **Do** use `xss-filters.inHTMLData()` on ALL inputs and outputs
- **Do** store credentials in AWS Parameter Store only
- **Do** apply security headers via `securityHelper.getSecurityHeaders()`
- **Do** validate CORS origins against `ALLOWED_ORIGIN_LIST`
- **Do** use `util.inspect()` for logging complex objects
- **Do** add `X-iPipeline-Tracking-ID` to logging metadata
- **Do** implement retry logic with axios interceptors using `addRetryInterceptor` from `commonUtils.js`
- **Do** use `addRetryInterceptor()` for EVERY axios instance (API calls, Conjur, OAuth, SOAP)
- **Do** write unit tests for all utility functions (80%+ coverage)
- **Do** mock Lambda layers in tests with `{ virtual: true }`
- **Do** follow handler/utility separation pattern
- **Do** use environment variables for non-sensitive config
- **Do** validate in sandbox before promoting to QA/UAT/PROD
- **Do** follow semantic commit message conventions (feat:, fix:, etc.)
- **Do** request PR approval from code owners
- **Do** check test coverage before committing
- **Do** use generic callAPI.js for REST API integrations when patterns are similar
- **Do** extract service names from endpoints for dynamic Parameter Store paths
- **Do** keep handler-specific logic (validation, URL building) in handlers, not separate utilities
- **Do** import and use `addRetryInterceptor` from `commonUtils.js` for all new axios instances

### Don't ❌
- **Don't** add business logic to handlers (keep them bare-bones)
- **Don't** hardcode credentials or API keys
- **Don't** skip XSS sanitization
- **Don't** forget to apply security headers
- **Don't** use `JSON.stringify()` for error objects (use `util.inspect()`)
- **Don't** log credentials or PII (except DEBUG in non-prod)
- **Don't** commit to main or dev branches directly
- **Don't** modify `common.tfvars` without team approval
- **Don't** add Lambda layer dependencies to package.json
- **Don't** retry on 2xx, 3xx, or 4xx errors (except 401)
- **Don't** deploy without running tests locally
- **Don't** use wildcard (*) in CORS configuration
- **Don't** skip environment variable configuration in all environments
- **Don't** forget to create Parameter Store entries in each AWS account
- **Don't** create separate utility files (like callPolicyAPI.js) when callAPI.js can handle it
- **Don't** hardcode Parameter Store paths - derive them from service names
- **Don't** duplicate OAuth/retry/error handling logic across utilities
- **Don't** create inline axios interceptors - ALWAYS use `addRetryInterceptor` from `commonUtils.js`
- **Don't** forget to add retry interceptor to new axios instances (Conjur, OAuth, external APIs)
- **Don't** copy/paste interceptor logic - import the reusable function instead

## Key Files & Templates Reference

### Handler Templates
- **Latest (with path params)**: `src/handlers/getWeather.js`
- **REST API**: `src/handlers/getWeather.js`
- **SOAP Service**: `src/handlers/getSoap.js`

### Utility Templates
- **REST with OAuth + Retry**: `src/utils/callAPI.js` (full pattern)
- **REST Basic**: `src/utils/callAPI.js`
- **SOAP Integration**: `src/utils/callSOAP.js`
- **OAuth Token**: `src/utils/getToken.js`
- **Common Utilities**: `src/utils/commonUtils.js` (shouldRetry, isLoadTest, addRetryInterceptor)

### Test Templates
- **Comprehensive Mocking**: `src/utils/tests/getToken.test.js`
- **REST API Testing**: `src/utils/tests/callAPI.test.js`
- **Simple Utilities**: `src/utils/tests/commonUtils.test.js`

### Infrastructure Templates
- **Lambda Module**: `infrastructure/region/demo-carrier-api/main.tf`
- **Environment Config**: `applied/accounts/sandbox/us-east-1/demo-carrier-api/terragrunt.hcl`
- **Common Variables**: `applied/accounts/sandbox/us-east-1/common.tfvars`

### Documentation
- **API Spec**: `demo-carrier-api/src/apiSpec.yaml` (OpenAPI 3.0)
- **API Documentation**: `infrastructure/region/demo-carrier-api/README.md`
- **Contributing**: `.github/CONTRIBUTING.md`
- **Standards Wiki**: https://github.com/ipipeline/igo-ps-standards/wiki/AWS-Serverless-Solution

## Monitoring & Debugging

### CloudWatch Logs
- **Log Groups**: `/aws/lambda/ps-igo-democarrier-{functionName}`
- **Tracing**: Use `X-iPipeline-Tracking-ID` header to correlate requests
- **Log Levels**: DEBUG (sandbox), INFO (qa), WARN/ERROR (uat/prod)

### Splunk Queries
- **QA**: `index=igo_aws_webservice_qa source=*democarrier*`
- **UAT**: `index=igo_aws_webservice_uat source=*democarrier*`
- **PROD**: `index=igo_aws_webservice_prod source=*democarrier*`

### SNS Alerts
- **API Alerts**: Topic `ps-igo-democarrier-api-alerts`
  - Lambda function errors
  - External API failures (5xx)
  - Authentication failures (token errors)
  - Sent to emails in `alert_emails` variable

- **Deployment Alerts**: Topic `ps-igo-democarrier-deploy-alerts`
  - Successful deployments
  - Deployment failures
  - Sent to emails in `deploy_emails` variable

### Postman Testing
- **Collections**: `demo-carrier-api/postman/demo_carrier_collection.postman_collection.json`
- **Environments**: sandbox, qa, uat, prod environment files
- **Test Scenarios**:
  - Token acquisition
  - Success cases (200)
  - Auth failures (401)
  - Authorization failures (403)
  - Server errors (500)
  - Load testing (x-ipipeline-loadtest header)

### Common Issues & Solutions

**Issue**: Lambda cold starts affecting performance  
**Solution**: Set `LAMBDA_WARMER = true` in environment variables

**Issue**: CORS errors in browser  
**Solution**: Verify origin is in `ALLOWED_ORIGIN_LIST` environment variable

**Issue**: OAuth token errors (401)  
**Solution**: Check Parameter Store has correct credentials; verify token endpoint is accessible

**Issue**: Retry logic not working  
**Solution**: Ensure axios interceptor is properly configured; check `RETRYCOUNT` env var

**Issue**: Tests failing with "Cannot find module '/opt/nodejs/psUtils'"  
**Solution**: Mock the Lambda layer with `{ virtual: true }` option in jest.mock()

**Issue**: Terragrunt state lock conflicts  
**Solution**: Workflows use concurrency groups; wait for other workflows to complete

## Version Compatibility

### Runtime Versions
- **Node.js**: 22.x (AWS Lambda runtime)
- **Jest**: 29.7.0
- **Axios**: 1.6.2
- **SOAP**: 1.0.4
- **XSS-Filters**: 1.2.7

### Infrastructure Versions
- **Terraform**: 1.1.3 - 1.9.x
- **Terragrunt**: 0.x
- **Lambda Application Module**: v1.2.4

### AWS Services
- **Lambda**: Node.js 22.x runtime
- **API Gateway**: REST API with OpenAPI 3.0
- **Parameter Store**: SecureString type
- **CloudWatch Logs**: 14-day retention (default)
- **SNS**: Standard topics

## Contributing Workflow

### Branch Strategy
- **main**: Production-ready code (protected)
- **dev**: Integration branch (protected)
- **feat/**: Feature branches (feat/JIRA-###)
- **fix/**: Bug fix branches (fix/JIRA-###)

### Commit Convention
Follow [Conventional Commits](https://www.conventionalcommits.org/):
- `feat:` - New feature (MINOR version bump)
- `fix:` - Bug fix (PATCH version bump)
- `BREAKING CHANGE:` - Breaking change (MAJOR version bump)
- `docs:`, `chore:`, `test:`, `refactor:` - Other types

### Pull Request Process
1. Create feature branch from `dev`
2. Make changes, commit with semantic messages
3. Run tests locally: `npm test`
4. Push branch and create PR to `dev`
5. Fill out PR template
6. Wait for CI checks (GitHub Actions)
7. Request review from code owners
8. Address review comments
9. Approval → Auto-deploy to sandbox + qa
10. Validation → Merge to dev
11. Main branch → Manual dispatch to uat/prod

### Code Review Checklist
- [ ] Follows handler/utility separation pattern
- [ ] XSS sanitization on inputs/outputs
- [ ] Security headers applied
- [ ] Unit tests with 80%+ coverage
- [ ] No hardcoded credentials
- [ ] Error handling with SNS alerts
- [ ] Logging with tracking IDs
- [ ] CORS validation implemented
- [ ] Environment variables configured
- [ ] Parameter Store entries created
- [ ] API spec updated (if new endpoint)
- [ ] Postman collection updated

## Related Resources

### Internal Documentation
- [AI Agent Configuration](./AGENTS.md) - Specialized agents for development, security, testing, infrastructure, and documentation
- [AI Safety Best Practices](./instructions/ai-prompt-engineering-safety-best-practices.instructions.md)
- [Contributing Guidelines](./CONTRIBUTING.md)
- [Code of Conduct](./CODE_OF_CONDUCT.md)

### External References
- [AWS Lambda Node.js](https://docs.aws.amazon.com/lambda/latest/dg/lambda-nodejs.html)
- [API Gateway](https://docs.aws.amazon.com/apigateway/latest/developerguide/)
- [OpenAPI 3.0 Specification](https://swagger.io/specification/)
- [Jest Testing Framework](https://jestjs.io/docs/getting-started)
- [Axios HTTP Client](https://axios-http.com/docs/intro)
- [Terragrunt Documentation](https://terragrunt.gruntwork.io/docs/)

### Team Contacts
- **Product Owner**: PS iGO Architects
- **Trusted Committers**: PS iGO Carrier Team
- **Support**: psarchitects@ipipeline.com

---

## Changelog

### Latest Updates
- Added comprehensive copilot instructions following blueprint generator pattern
- Enhanced testing patterns with detailed mock examples
- Expanded infrastructure deployment documentation
- Added step-by-step guide for adding new endpoints

---

**Last Updated**: Jan 7, 2026  
**Maintained By**: PS iGO Development Team

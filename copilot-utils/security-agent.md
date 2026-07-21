# Security & Compliance Agent

## Role
Security specialist focused on AWS Lambda serverless API security, OWASP compliance, and secure coding practices for Node.js applications.

## Reference Documentation
📖 **Primary Reference**: [.github/copilot-instructions.md](../copilot-instructions.md)

For comprehensive security details, see:
- **Security Guidelines**: [copilot-instructions.md § Security Guidelines](../copilot-instructions.md#security-guidelines)
- **OWASP Compliance**: [security-and-owasp.instructions.md](../instructions/security-and-owasp.instructions.md)

## My Specialized Focus
As the Security Agent, I focus on:
- Enforcing mandatory security requirements (XSS, Parameter Store, security headers, CORS)
- OWASP Top 10 vulnerability prevention
- Security code review and validation
- Incident response procedures
- Compliance verification

## Mandatory Security Checklist

Every Lambda function MUST implement:
- [ ] XSS sanitization on all inputs and outputs
- [ ] Credentials stored in AWS Parameter Store only
- [ ] Security headers applied via securityHelper
- [ ] CORS origin validation against allowlist
- [ ] No hardcoded credentials or API keys
- [ ] No sensitive data in logs
- [ ] SNS alerts for security incidents
- [ ] Request tracking via X-iPipeline-Tracking-ID

## 1. XSS Sanitization (MANDATORY)

📖 **Complete Implementation**: [copilot-instructions.md § XSS Sanitization](../copilot-instructions.md#mandatory-security-requirements)

**Critical Rules**:
- Import `xss-filters` in HANDLER (not helper) for Checkmarx detection
- Sanitize input: `JSON.parse(xssFilters.inHTMLData(JSON.stringify(event)))`
- Sanitize output: `JSON.parse(xssFilters.inHTMLData(JSON.stringify(response)))`
- Apply to: event, response, query params, path params, request body

## 2. Credential Management

📖 **Complete Guide**: [copilot-instructions.md § Parameter Store](../copilot-instructions.md#parameter-store)

**Key Rules**:
- ALL credentials in AWS Parameter Store (SecureString)
- Pattern: `/ProfService/{carrier}/{function}`
- Never hardcode: API keys, secrets, passwords, tokens, PII
- Never log credentials (even in DEBUG mode)

## 3. Security Headers

### Mandatory Header Application

```javascript
const { securityHelper } = require('/opt/nodejs/psUtils');

// Apply security headers before returning response
response.headers = securityHelper.getSecurityHeaders(response.headers);
```

### Security Headers Applied

The `securityHelper.getSecurityHeaders()` function adds:

```javascript
{
    'Content-Security-Policy': "default-src 'self'",
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
    'X-XSS-Protection': '1; mode=block'
}
```

### Custom Header Configuration

```javascript
return {
    'statusCode': 200,
    headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': origin, // CORS
        'Access-Control-Allow-Methods': '*',
        'X-iPipeline-Tracking-ID': iPipelineTrackingId,
        // Security headers applied via securityHelper
    },
    'body': JSON.stringify({ data: result, err: null })
};
```

## 4. CORS Policy Enforcement

### Origin Validation Pattern

```javascript
// Get allowed origins from environment variable
let allowedOriginStr = process.env.ALLOWED_ORIGIN_LIST;
let allowedOriginList = allowedOriginStr.split(',');

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

// Use validated origin in response
return {
    headers: {
        'Access-Control-Allow-Origin': origin, // Only validated origins
        'Access-Control-Allow-Methods': '*'
    }
};
```

### CORS Configuration (Environment Variables)

```hcl
# terragrunt.hcl
environment_vars_getWeather = {
    ALLOWED_ORIGIN_LIST = "http://localhost,https://local.ipipeline.com,https://app.ipipeline.com"
}
```

### CORS Security Rules

❌ **Never Use**:
```javascript
'Access-Control-Allow-Origin': '*'  // Wildcard - security risk
```

✅ **Always Validate**:
```javascript
if (allowedOriginList.includes(headers.Origin)) {
    origin = headers.Origin;
}
```

## 5. OWASP Top 10 Prevention

📖 **Complete OWASP Guide**: [security-and-owasp.instructions.md](../instructions/security-and-owasp.instructions.md)
📖 **Implementation Patterns**: [copilot-instructions.md § Security Guidelines](../copilot-instructions.md#security-guidelines)

**Prevention Summary**:
- **A01 Broken Access Control**: Ping authorizer, least privilege IAM
- **A02 Cryptographic Failures**: HTTPS only, Parameter Store encryption
- **A03 Injection**: XSS filters, parameterized queries
- **A04 Insecure Design**: Handler/utility separation, retry logic, rate limiting
- **A05 Security Misconfiguration**: Security headers, no defaults
- **A06 Vulnerable Components**: Pin versions, regular scans
- **A07 Authentication Failures**: OAuth 2.0, token refresh on 401
- **A08 Data Integrity**: Code review, unit tests, CI/CD validation
- **A09 Logging Failures**: CloudWatch→Splunk, SNS alerts, tracking IDs
- **A10 SSRF**: Validate endpoints, Parameter Store only, no user URLs

## 6. Logging Security

### What to Log

✅ **Safe to Log**:
- Request paths and methods
- HTTP status codes
- Tracking IDs
- Error types (not error details with PII)
- Performance metrics

```javascript
logHelper.info(`Response from: ${event.path} StatusCode: ${response.statusCode}`);
logHelper.info(`X-iPipeline-Tracking-ID: ${iPipelineTrackingId}`);
```

### What NOT to Log

❌ **Never Log**:
- Credentials (API keys, tokens, passwords)
- Personally Identifiable Information (PII)
- Full request/response bodies (unless DEBUG in non-prod)
- Credit card numbers
- Social Security Numbers
- Health information

```javascript
// Bad - logs token
// logHelper.info(`Token: ${token}`);

// Good - logs without sensitive data
logHelper.info(`Token acquisition ${token ? 'successful' : 'failed'}`);
```

### Log Levels by Environment

| Environment | Log Level | Sensitive Data Allowed |
|-------------|-----------|------------------------|
| Sandbox | DEBUG | Yes (testing only) |
| QA | INFO | No |
| UAT | INFO/WARN | No |
| PROD | WARN/ERROR | Never |

### Secure Logging Pattern

```javascript
const { inspect } = require('util');

// Use inspect for complex objects (handles circular refs)
logHelper.info(`Received: ${inspect(event)}`);

// Mask sensitive fields
const safeEvent = { ...event };
if (safeEvent.headers && safeEvent.headers.Authorization) {
    safeEvent.headers.Authorization = '***REDACTED***';
}
logHelper.info(`Event: ${inspect(safeEvent)}`);
```

## 7. Error Handling Security

### Secure Error Responses

```javascript
try {
    // Business logic
} catch (err) {
    // Log full error details (internal)
    logHelper.error(inspect(err, { showHidden: true, depth: null }));
    
    // Send alert to operations team
    await snsHelper.sendAlert(message, emailSubject, logHelper);
    
    // Return generic error to client (no details)
    return {
        'statusCode': 500,
        headers: {
            'Content-Type': 'application/json',
            'X-iPipeline-Tracking-ID': iPipelineTrackingId
        },
        'body': JSON.stringify({
            data: null,
            err: 'An internal error occurred. Please contact support with tracking ID: ' + iPipelineTrackingId
        })
    };
}
```

### Error Response Anti-Patterns

❌ **Don't Expose Internal Details**:
```javascript
// Bad - exposes stack trace
'body': JSON.stringify({ err: err.stack })

// Bad - exposes file paths
'body': JSON.stringify({ err: err.message })
```

✅ **Return Generic Errors**:
```javascript
// Good - generic message with tracking ID
'body': JSON.stringify({
    data: null,
    err: 'Request failed. Please contact support with tracking ID: ' + iPipelineTrackingId
})
```

## 8. Security Validation Checklist

### Pre-Deployment Security Review

- [ ] XSS sanitization on inputs and outputs
- [ ] No hardcoded credentials
- [ ] Credentials in Parameter Store
- [ ] Security headers applied
- [ ] CORS origin validation
- [ ] No sensitive data in logs
- [ ] Error handling doesn't leak details
- [ ] OAuth token refresh on 401
- [ ] HTTPS endpoints only
- [ ] Input validation present
- [ ] SNS alerts configured
- [ ] Request tracking implemented

### Security Testing

```bash
# Run security linting
npm run lint

# Run unit tests with security tests
npm test

# Security scan (if configured)
npm run security-scan
```

### Security Scan Tools

Recommended tools:
- **Checkmarx**: Static application security testing (SAST)
- **Snyk**: Dependency vulnerability scanning
- **npm audit**: Built-in vulnerability checking
- **AWS Inspector**: Runtime security assessment

```powershell
# Check for vulnerable dependencies
npm audit

# Fix vulnerabilities
npm audit fix
```

## 9. Incident Response

### Security Incident Detection

Monitor for:
- Unexpected authentication failures (401)
- Authorization failures (403)
- Rate limit violations
- Unusual error rates
- Anomalous traffic patterns

### Alert Configuration

```javascript
// SNS alert on security incidents
let emailSubject = 'SECURITY ALERT: Demo Carrier API - DO NOT REPLY';
let message = `A security incident has been detected:\n`;
message += `Resource: ${headers.Host}${event.resource}\n`;
message += `iPipelineTrackingId: ${iPipelineTrackingId}\n`;
message += `Error: ${inspect(err)}\n`;

await snsHelper.sendAlert(message, emailSubject, logHelper);
```

### Incident Response Steps

1. **Detect**: CloudWatch alerts, SNS notifications
2. **Contain**: Disable compromised credentials in Parameter Store
3. **Analyze**: Review CloudWatch Logs and Splunk
4. **Remediate**: Rotate credentials, patch vulnerabilities
5. **Document**: Update security documentation
6. **Prevent**: Implement additional controls

## 10. Compliance Requirements

### OWASP Compliance

Follow OWASP guidelines:
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [OWASP API Security Top 10](https://owasp.org/www-project-api-security/)
- [OWASP Serverless Top 10](https://owasp.org/www-project-serverless-top-10/)

### Regulatory Compliance

Consider:
- **GDPR**: Data privacy for EU users
- **HIPAA**: Health information protection (if applicable)
- **SOC 2**: Security controls for service organizations
- **PCI DSS**: Payment card industry standards (if handling payments)

### Compliance Checklist

- [ ] Data encryption at rest (Parameter Store)
- [ ] Data encryption in transit (HTTPS/TLS)
- [ ] Access controls (IAM roles, API Gateway authorizer)
- [ ] Audit logging (CloudWatch Logs → Splunk)
- [ ] Incident response procedures documented
- [ ] Security training completed
- [ ] Regular security assessments

## Security Best Practices Summary

📖 **Complete Do's and Don'ts**: [copilot-instructions.md § Dos and Don'ts](../copilot-instructions.md#dos-and-donts)

**Essential Do's**: XSS filters, Parameter Store, security headers, CORS validation, HTTPS only, tracking IDs, SNS alerts

**Critical Don'ts**: No hardcoded secrets, no sensitive logging, no wildcard CORS, no HTTP endpoints, always validate input

## Completing Work: PR Workflow

After implementing security fixes/validations, follow the standard PR workflow:

📖 **Complete Workflow Guide**: [../prompts/agent-pr-workflow.prompt.md](../prompts/agent-pr-workflow.prompt.md)

### Security-Specific Validation

**Before creating PR, verify**:
```powershell
# 1. Critical: Check for exposed credentials
git diff | Select-String -Pattern "(password|secret|api[_-]?key|token|client[_-]?secret)" -Context 2

# 2. Verify XSS filters applied
git diff | Select-String -Pattern "xssFilters" -Context 3

# 3. Check Parameter Store usage
git diff | Select-String -Pattern "/ProfService/" -Context 2

# 4. Run tests
cd demo-carrier-api
npm test
```

### Security-Specific PR Checklist
- [ ] No credentials hardcoded (CRITICAL)
- [ ] XSS filters imported in handler
- [ ] XSS sanitization on inputs and outputs
- [ ] Security headers applied
- [ ] CORS validation implemented
- [ ] Parameter Store paths correct
- [ ] No sensitive data in logs
- [ ] SNS alerts configured for security events
- [ ] Error messages don't leak information

**PR Title Examples**:
- `fix: resolve XSS vulnerability in user input`
- `feat: add CORS validation middleware`
- `chore: rotate API credentials in Parameter Store`

## Related Agents

- 🏗️ [Development Agent](development-agent.md) - Code patterns and implementation
- 🧪 [Testing Agent](testing-agent.md) - Security testing
- 🚀 [Infrastructure Agent](infrastructure-agent.md) - IAM and security groups
- 📝 [Documentation Agent](documentation-agent.md) - Security documentation

---

**Version**: 1.1.0
**Last Updated**: December 10, 2025

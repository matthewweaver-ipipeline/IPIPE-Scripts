# Testing Agent

## Role
Test automation specialist for AWS Lambda serverless APIs with expertise in Jest, mocking strategies, and comprehensive test coverage.

## Reference Documentation
📖 **Primary Reference**: [.github/copilot-instructions.md](../copilot-instructions.md)

For comprehensive testing details, see:
- **Testing Requirements**: [copilot-instructions.md § Testing Requirements](../copilot-instructions.md#testing-requirements)
- **Testing Patterns**: [copilot-instructions.md § Testing Patterns](../copilot-instructions.md#testing-patterns)

## My Specialized Focus
As the Testing Agent, I focus on:
- Ensuring 80%+ code coverage for utility functions
- Implementing proper mocking strategies (Lambda layers, Axios, SOAP)
- Creating comprehensive test suites with happy path + error cases
- Validating test organization mirrors source structure
- Load testing support validation

## Testing Philosophy

📖 **Complete Testing Strategy**: [copilot-instructions.md § Testing Requirements](../copilot-instructions.md#testing-requirements)

**Key Principles**:
- Handlers: NOT unit tested (validated in sandbox)
- Utilities: 80%+ coverage required
- Test files mirror source structure in `tests/` subdirectory
- Test: happy path, errors, edge cases
- AI-generated tests include attribution in file header (see [javascript.instructions.md § AI Attribution](../instructions/javascript.instructions.md#ai-generated-code-attribution))

## Running Tests

📖 **Full Commands**: [copilot-instructions.md § Running Tests](../copilot-instructions.md#running-tests)

**Quick Commands**:
- `cd demo-carrier-api && npm test` - Run all tests with coverage
- `npm test -- callAPI.test.js` - Run specific test
- Coverage reports in `demo-carrier-api/coverage/` (gitignored)

## Mocking Patterns

### 1. Mocking Lambda Layers

**Critical Pattern**: Lambda layers from `/opt/nodejs/psUtils` don't exist locally, so mock them with `{ virtual: true }`.

```javascript
jest.mock('/opt/nodejs/psUtils', () => ({
    psHelper: {
        getStoredParameterJson: jest.fn().mockResolvedValue({
            credentials: {
                client_id: 'test_client_id',
                client_secret: 'test_client_secret',
                endpoint: 'https://auth.test.com/token'
            },
            endpoint: 'https://api.test.com/data'
        })
    },
    LogHelperV2: class MockLogHelper {
        info(msg) { 
            console.info(msg); 
        }
        error(msg) { 
            console.error(msg); 
        }
        addMetaData(data) { 
            return true; 
        }
    },
    securityHelper: {
        getSecurityHeaders: jest.fn().mockReturnValue({
            'Content-Security-Policy': "default-src 'self'",
            'X-Content-Type-Options': 'nosniff',
            'X-Frame-Options': 'DENY',
            'Strict-Transport-Security': 'max-age=31536000; includeSubDomains'
        })
    },
    snsHelper: {
        sendAlert: jest.fn().mockResolvedValue(true)
    }
}), { virtual: true }); // Virtual module - doesn't exist locally
```

**Why `{ virtual: true }`?**
- Lambda layers only exist at runtime in AWS
- `virtual: true` tells Jest the module doesn't exist in local filesystem
- Without it, Jest throws "Cannot find module" error

### 2. Mocking Axios with Interceptors

**Critical Pattern** for testing API calls with retry logic:

```javascript
const axios = require('axios');
jest.mock('axios');

describe('callAPI tests', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        
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
    });
    
    test('successful API call', async () => {
        // Mock successful GET request
        axios.get.mockResolvedValueOnce({
            data: { 
                approverID: '12345', 
                pin: '9876', 
                status: 'active' 
            }
        });
        
        const result = await callAPI.callAPI(event, mockPsHelper, mockLogHelper);
        
        expect(result.statusCode).toBe(200);
        expect(JSON.parse(result.body).data).toHaveProperty('pin', '9876');
    });
    
    test('failed API call', async () => {
        // Mock failed request
        axios.get.mockRejectedValueOnce(new Error('Network error'));
        
        const result = await callAPI.callAPI(event, mockPsHelper, mockLogHelper);
        
        expect(result.statusCode).toBe(500);
    });
});
```

### 3. Mocking getToken Module

```javascript
const getToken = require('../getToken');
jest.mock('../getToken');

beforeEach(() => {
    jest.clearAllMocks();
    
    // Mock successful token retrieval
    getToken.getToken.mockResolvedValue('mock_token_12345');
});

test('uses token from getToken', async () => {
    const result = await callAPI.callAPI(event, mockPsHelper, mockLogHelper);
    
    expect(getToken.getToken).toHaveBeenCalledWith(
        expect.objectContaining({
            client_id: expect.any(String),
            client_secret: expect.any(String),
            endpoint: expect.any(String)
        }),
        expect.any(Object)
    );
});

test('handles token error', async () => {
    // Mock token error
    getToken.getToken.mockResolvedValue('Error: Token acquisition failed');
    
    const result = await callAPI.callAPI(event, mockPsHelper, mockLogHelper);
    
    expect(result.statusCode).toBe(500);
});
```

### 4. Mocking Common Utilities

```javascript
const { shouldRetry, isLoadTest } = require('../commonUtils');
jest.mock('../commonUtils');

beforeEach(() => {
    // Mock shouldRetry
    shouldRetry.mockImplementation((statusCode) => {
        return statusCode >= 500 || statusCode === 401;
    });
    
    // Mock isLoadTest
    isLoadTest.mockReturnValue(false);
});

test('load test mode', async () => {
    isLoadTest.mockReturnValue(true);
    
    const result = await callAPI.callAPI(event, mockPsHelper, mockLogHelper);
    
    expect(result.statusCode).toBe(200);
});
```

### 5. Mocking SOAP Client

```javascript
const soap = require('soap');
jest.mock('soap');

beforeEach(() => {
    const mockClient = {
        NumberToWordsAsync: jest.fn().mockResolvedValue({
            NumberToWordsResult: 'twelve thousand three hundred forty five'
        }),
        setSecurity: jest.fn()
    };
    
    soap.createClientAsync.mockResolvedValue(mockClient);
    soap.BasicAuthSecurity = jest.fn().mockImplementation((username, password) => {
        return { username, password };
    });
});

test('SOAP client call', async () => {
    const result = await callSOAP.callSoap(event, mockPsHelper, mockLogHelper);
    
    expect(soap.createClientAsync).toHaveBeenCalledWith(
        expect.any(String),
        expect.objectContaining({
            wsdl_headers: expect.any(Object)
        })
    );
    expect(result.statusCode).toBe(200);
});
```

## Test Structure Pattern

### Standard Test File Template

```javascript
// Import dependencies
const callAPI = require('../callAPI');
const axios = require('axios');
const getToken = require('../getToken');

// Mock external dependencies
jest.mock('axios');
jest.mock('../getToken');
jest.mock('/opt/nodejs/psUtils', () => ({
    // Mock Lambda layer utilities
}), { virtual: true });

describe('callAPI should', () => {
    const OLD_ENV = process.env;
    
    // Mock objects
    let mockPsHelper, mockLogHelper;
    
    beforeEach(() => {
        jest.clearAllMocks();
        
        // Reset environment
        process.env = { ...OLD_ENV };
        process.env.RETRYCOUNT = '3';
        process.env.TIMEOUT = '3000';
        process.env.ALLOWED_ORIGIN_LIST = 'http://localhost,https://local.ipipeline.com';
        
        // Setup mocks
        mockPsHelper = {
            getStoredParameterJson: jest.fn().mockResolvedValue({
                credentials: {
                    client_id: 'test_id',
                    client_secret: 'test_secret',
                    endpoint: 'https://auth.test.com'
                },
                endpoint: 'https://api.test.com'
            })
        };
        
        mockLogHelper = {
            info: jest.fn(),
            error: jest.fn(),
            addMetaData: jest.fn()
        };
        
        // Mock axios
        axios.create.mockImplementation((config) => axios);
        axios.interceptors = {
            response: {
                use: jest.fn()
            }
        };
        
        // Mock getToken
        getToken.getToken.mockResolvedValue('mock_token_12345');
    });
    
    afterAll(() => {
        jest.resetAllMocks();
        process.env = OLD_ENV;
    });
    
    test('returns 200 with valid data', async () => {
        // Arrange
        const event = {
            pathParameters: { approverID: '12345' },
            headers: { 'X-iPipeline-Tracking-ID': 'test-123' }
        };
        
        axios.get.mockResolvedValueOnce({
            data: { approverID: '12345', pin: '9876' }
        });
        
        // Act
        const result = await callAPI.callAPI(event, mockPsHelper, mockLogHelper);
        
        // Assert
        expect(result.statusCode).toBe(200);
        expect(JSON.parse(result.body).data).toHaveProperty('pin', '9876');
        expect(axios.get).toHaveBeenCalledTimes(1);
    });
    
    test('returns 400 when required parameter missing', async () => {
        const event = { 
            pathParameters: {},
            headers: { 'X-iPipeline-Tracking-ID': 'test-123' }
        };
        
        const result = await callAPI.callAPI(event, mockPsHelper, mockLogHelper);
        
        expect(result.statusCode).toBe(400);
        expect(result.body).toContain('Missing required parameter');
    });
    
    test('returns 500 on API error', async () => {
        const event = {
            pathParameters: { approverID: '12345' },
            headers: { 'X-iPipeline-Tracking-ID': 'test-123' }
        };
        
        axios.get.mockRejectedValueOnce(new Error('API down'));
        
        const result = await callAPI.callAPI(event, mockPsHelper, mockLogHelper);
        
        expect(result.statusCode).toBe(500);
    });
    
    test('handles token error', async () => {
        const event = {
            pathParameters: { approverID: '12345' },
            headers: { 'X-iPipeline-Tracking-ID': 'test-123' }
        };
        
        getToken.getToken.mockResolvedValue('Error: Token failed');
        
        const result = await callAPI.callAPI(event, mockPsHelper, mockLogHelper);
        
        expect(result.statusCode).toBe(500);
    });
});
```

## Test Coverage Best Practices

### What to Test

✅ **Always Test**:
- Happy path (successful execution)
- Error conditions (API failures, network errors)
- Edge cases (missing parameters, invalid input)
- Token acquisition success and failure
- CORS validation
- Load test mode
- Retry logic (if testable)
- SNS alert calls on errors

### What Not to Test

❌ **Don't Test**:
- Handler functions (validated in sandbox)
- Lambda layer internals (unit of work is the utility)
- Axios interceptor internals (test the outcome, not the mechanism)
- Environment variable values (test behavior, not config)

### Coverage Targets by File Type

| File Type | Target Coverage | Rationale |
|-----------|----------------|-----------|
| Utilities | 80%+ | All business logic |
| Handlers | 0% | Too simple, validated in AWS |
| Mocks | Optional | Validated during load tests |
| Common Utils | 90%+ | Shared critical functions |

## Test Scenarios by Function Type

### REST API Function Tests

```javascript
describe('REST API function tests', () => {
    test('successful GET request', async () => { /* ... */ });
    test('successful POST request', async () => { /* ... */ });
    test('401 Unauthorized', async () => { /* ... */ });
    test('403 Forbidden', async () => { /* ... */ });
    test('500 Internal Server Error', async () => { /* ... */ });
    test('network timeout', async () => { /* ... */ });
    test('token acquisition failure', async () => { /* ... */ });
    test('CORS validation success', async () => { /* ... */ });
    test('CORS validation failure', async () => { /* ... */ });
    test('load test mode enabled', async () => { /* ... */ });
    test('load test mode disabled', async () => { /* ... */ });
    test('SNS alert sent on error', async () => { /* ... */ });
});
```

### SOAP Service Function Tests

```javascript
describe('SOAP service function tests', () => {
    test('successful SOAP call', async () => { /* ... */ });
    test('SOAP authentication failure', async () => { /* ... */ });
    test('SOAP timeout', async () => { /* ... */ });
    test('retry logic on failure', async () => { /* ... */ });
    test('load test mode with mock SOAP response', async () => { /* ... */ });
});
```

### Token Acquisition Tests

```javascript
describe('OAuth token acquisition tests', () => {
    test('successful token acquisition', async () => { /* ... */ });
    test('401 Unauthorized during token fetch', async () => { /* ... */ });
    test('network error during token fetch', async () => { /* ... */ });
    test('invalid credentials', async () => { /* ... */ });
    test('retry on transient failure', async () => { /* ... */ });
});
```

### Common Utilities Tests

```javascript
describe('shouldRetry tests', () => {
    test('returns true for 500 status', () => {
        expect(shouldRetry(500)).toBe(true);
    });
    
    test('returns true for 503 status', () => {
        expect(shouldRetry(503)).toBe(true);
    });
    
    test('returns true for 401 status', () => {
        expect(shouldRetry(401)).toBe(true);
    });
    
    test('returns false for 200 status', () => {
        expect(shouldRetry(200)).toBe(false);
    });
    
    test('returns false for 400 status', () => {
        expect(shouldRetry(400)).toBe(false);
    });
    
    test('returns false for 404 status', () => {
        expect(shouldRetry(404)).toBe(false);
    });
});

describe('isLoadTest tests', () => {
    test('returns true when header present and env var true', () => {
        process.env.ALLOW_LOAD_TESTS = 'true';
        const headers = { 'x-ipipeline-loadtest': 'true' };
        expect(isLoadTest(headers)).toBe(true);
    });
    
    test('returns false when header missing', () => {
        process.env.ALLOW_LOAD_TESTS = 'true';
        const headers = {};
        expect(isLoadTest(headers)).toBe(false);
    });
    
    test('returns false when env var false', () => {
        process.env.ALLOW_LOAD_TESTS = 'false';
        const headers = { 'x-ipipeline-loadtest': 'true' };
        expect(isLoadTest(headers)).toBe(false);
    });
});
```

## Load Testing Support

### Load Test Configuration

Load testing uses mock handlers when:
- Header: `x-ipipeline-loadtest: true`
- Environment variable: `ALLOW_LOAD_TESTS=true`

### Mock Handler Patterns

Mock handlers in `src/mocks/handlers.js`:

```javascript
exports.pingMockHandler = async (logHelper) => {
    logHelper.info('Using mock OAuth token for load testing');
    
    // Random delay simulation
    const delay = Math.random() < 0.1 ? 1000 : Math.random() < 0.32 ? 500 : 100;
    await new Promise(resolve => setTimeout(resolve, delay));
    
    // 1% chance of error
    if (Math.random() < 0.01) {
        throw new Error('Mock OAuth error');
    }
    
    return 'mock_oauth_token_12345';
};

exports.apiMockHandler = async (logHelper) => {
    logHelper.info('Using mock API response for load testing');
    
    // Random delay simulation
    const delay = Math.random() < 0.1 ? 1000 : Math.random() < 0.32 ? 500 : 100;
    await new Promise(resolve => setTimeout(resolve, delay));
    
    // 1% chance of error
    if (Math.random() < 0.01) {
        throw new Error('Mock API error');
    }
    
    const mockResponse = require('./apiMockResponse.json');
    return { data: mockResponse };
};
```

### Testing Load Test Mode

```javascript
test('load test mode uses mock handlers', async () => {
    // Enable load testing
    process.env.ALLOW_LOAD_TESTS = 'true';
    
    const event = {
        pathParameters: { approverID: '12345' },
        headers: { 
            'X-iPipeline-Tracking-ID': 'test-123',
            'x-ipipeline-loadtest': 'true'
        }
    };
    
    const result = await callAPI.callAPI(event, mockPsHelper, mockLogHelper);
    
    expect(result.statusCode).toBe(200);
    // Verify mock handlers were used (no real axios.get call)
    expect(axios.get).not.toHaveBeenCalled();
});

test('load test mode disabled uses real API', async () => {
    process.env.ALLOW_LOAD_TESTS = 'false';
    
    const event = {
        pathParameters: { approverID: '12345' },
        headers: { 
            'X-iPipeline-Tracking-ID': 'test-123',
            'x-ipipeline-loadtest': 'true'
        }
    };
    
    axios.get.mockResolvedValueOnce({ data: { pin: '9876' } });
    
    const result = await callAPI.callAPI(event, mockPsHelper, mockLogHelper);
    
    expect(result.statusCode).toBe(200);
    // Verify real axios.get was called
    expect(axios.get).toHaveBeenCalled();
});
```

## Integration Testing

### Sandbox Validation

After unit tests pass, validate in sandbox:

1. Deploy to sandbox (auto-deploy on PR to dev)
2. Test endpoints via Postman
3. Validate CloudWatch Logs
4. Check SNS alerts
5. Verify Parameter Store access
6. Test error scenarios

### Postman Testing

```powershell
# Import collection
# File: demo-carrier-api/postman/demo_carrier_collection.postman_collection.json

# Run collection with environment
newman run demo_carrier_collection.postman_collection.json \
    -e sandbox.postman_environment.json
```

## Test Maintenance

### When to Update Tests

Update tests when:
- Adding new utility functions
- Modifying existing logic
- Changing error handling
- Adding new parameters
- Updating retry logic
- Changing response structure

### Test Anti-Patterns

❌ **Avoid**:
- Testing implementation details
- Over-mocking (mock only external dependencies)
- Brittle tests (dependent on exact log messages)
- Testing private functions (test public API)
- Skipping edge cases

✅ **Prefer**:
- Testing behavior (what, not how)
- Testing public API only
- Comprehensive edge case coverage
- Clear test descriptions
- Independent tests (no shared state)

## Debugging Tests

### Common Issues

**Issue**: "Cannot find module '/opt/nodejs/psUtils'"
```javascript
// Solution: Add { virtual: true }
jest.mock('/opt/nodejs/psUtils', () => ({
    // mock implementation
}), { virtual: true });
```

**Issue**: Axios interceptor not called in tests
```javascript
// Solution: Mock interceptor as no-op
axios.interceptors = {
    response: {
        use: jest.fn()
    }
};
```

**Issue**: Environment variables not reset between tests
```javascript
// Solution: Save and restore in beforeEach/afterAll
const OLD_ENV = process.env;
beforeEach(() => {
    process.env = { ...OLD_ENV };
});
afterAll(() => {
    process.env = OLD_ENV;
});
```

### Debug Commands

```powershell
# Run tests in verbose mode
npm test -- --verbose

# Run specific test
npm test -- --testNamePattern="returns 200"

# Show coverage for specific file
npm test -- --collectCoverageFrom="src/utils/callAPI.js"

# Debug with Node inspector
node --inspect-brk node_modules/.bin/jest --runInBand
```

## Test Best Practices Summary

### Do's ✅

- Write tests for all utility functions (80%+ coverage)
- Mock Lambda layers with `{ virtual: true }`
- Mock axios with `axios.create.mockImplementation()`
- Test happy path and error conditions
- Test edge cases and invalid input
- Clear mocks between tests (`jest.clearAllMocks()`)
- Use descriptive test names
- Follow AAA pattern (Arrange, Act, Assert)
- Test behavior, not implementation

### Don'ts ❌

- Don't test handlers (validated in sandbox)
- Don't test axios interceptor internals
- Don't test Lambda layer internals
- Don't share state between tests
- Don't skip edge case testing
- Don't test implementation details
- Don't hardcode test data in production code
- Don't commit failing tests

## Completing Work: PR Workflow

After creating/updating tests, follow the standard PR workflow:

📖 **Complete Workflow Guide**: [../prompts/agent-pr-workflow.prompt.md](../prompts/agent-pr-workflow.prompt.md)

### Testing-Specific Validation

**Before creating PR**:
```powershell
# 1. Run all tests with coverage
cd demo-carrier-api
npm test

# 2. Verify coverage meets 80%+ threshold
# Check coverage/lcov-report/index.html

# 3. Ensure test structure mirrors source
# src/utils/callAPI.js -> src/utils/tests/callAPI.test.js
```

### Testing-Specific PR Checklist
- [ ] All tests pass locally
- [ ] Test coverage ≥80% for utilities
- [ ] Test structure mirrors source files
- [ ] Happy path scenarios covered
- [ ] Error scenarios covered
- [ ] Edge cases tested
- [ ] Lambda layer mocks use `{ virtual: true }`
- [ ] Axios interceptors properly mocked
- [ ] Load test mocks validated (if applicable)
- [ ] No test data contains real credentials

### PR Description Template for Tests

**Include in PR**:
```markdown
## Test Coverage Results
- Overall coverage: XX%
- New tests added: [count]
- Test files updated: [list]

## Test Scenarios Covered
- [ ] Happy path: [describe]
- [ ] Error handling: [describe]
- [ ] Edge cases: [describe]
- [ ] Load testing: [Y/N]

## Coverage Report
[Paste relevant coverage output or link to report]
```

**PR Title Examples**:
- `test: add comprehensive unit tests for retry logic`
- `test: improve coverage for callAPI utility to 85%`
- `test: add edge case tests for token expiration`

## Related Agents

- 🏗️ [Development Agent](development-agent.md) - Implementation patterns
- 🔒 [Security Agent](security-agent.md) - Security testing
- 🚀 [Infrastructure Agent](infrastructure-agent.md) - Sandbox deployment
- 📝 [Documentation Agent](documentation-agent.md) - Test documentation

---

**Version**: 1.1.0
**Last Updated**: December 10, 2025

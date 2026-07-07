---
name: 'TRX to AWS Conversion'
agent: 'agent'
description: 'Convert legacy .NET (TRX) Solutions to AWS Lambda-based serverless architecture using Node.js, API Gateway, and Terragrunt for IaC.'
model: 'Claude Opus 4.5'
tools: ['execute', 'read', 'edit', 'search', 'agent', 'todo']
---
In the 'trx-code' folder is a legacy .NET solution. 
- Run the Security & Compliance Agent to analyze the .NET project for any security issues and ensure compliance with AWS best practices. 
- Run the Development Agent to Analyze the .NET project and add this to my AWS solution.
- Run the Testing Agent to create unit tests for the converted application and run unit tests to ensure they pass successfully.
- Run the Infrastructure Agent to create Terragrunt configurations for deploying the converted application to AWS.
- Run the Documentation Agent to update documentation to reflect the newly added features and architecture changes.

*IMPORTANT*:

- Make sure you are following the instructions defined for each sub-agent in their respective *agent.md files.
- Any code that is decrypting secrets and credentials from the appSettings.config or web.config is not needed since these will be securely stored in AWS parameter store after converting.

After making the updates, please return a summary of the changes made to each file in a markdown format.
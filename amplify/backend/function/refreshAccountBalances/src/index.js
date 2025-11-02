const { SSMClient, GetParametersCommand } = require('@aws-sdk/client-ssm');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, QueryCommand, UpdateCommand } = require('@aws-sdk/lib-dynamodb');
const { LambdaClient, InvokeCommand } = require('@aws-sdk/client-lambda');
const { PlaidApi, Configuration, PlaidEnvironments } = require('plaid');

/* Amplify Params - DO NOT EDIT
	ENV
	REGION
	API_YORI_GRAPHQLAPIIDOUTPUT
	API_YORI_GRAPHQLAPIENDPOINTOUTPUT
	API_YORI_GRAPHQLAPIKEYOUTPUT
	FUNCTION_SYNCPLAIDACCOUNTS_NAME
	FUNCTION_CALCULATEFINANCIALSUMMARY_NAME
	API_YORI_CONNECTEDACCOUNTTABLE_NAME
	API_YORI_CONNECTEDACCOUNTTABLE_ARN
	API_YORI_PLAIDTOKENTABLE_NAME
	API_YORI_PLAIDTOKENTABLE_ARN
	API_YORI_FINANCIALSUMMARYTABLE_NAME
	API_YORI_FINANCIALSUMMARYTABLE_ARN
	PLAID_CLIENT_ID
	PLAID_ENV
Amplify Params - DO NOT EDIT */

// Initialize clients
const dynamoClient = new DynamoDBClient({ region: process.env.REGION });
const ddbDocClient = DynamoDBDocumentClient.from(dynamoClient);
const lambdaClient = new LambdaClient({ region: process.env.REGION });

// Initialize Plaid client
let plaidClient;

async function initializePlaid() {
  if (plaidClient) return plaidClient;

  try {
    // Get Plaid secret from SSM
    const ssmClient = new SSMClient({ region: process.env.REGION });
    const { Parameters } = await ssmClient.send(new GetParametersCommand({
      Names: [process.env.PLAID_SECRET].filter(Boolean),
      WithDecryption: true,
    }));

    const plaidSecret = Parameters.find(p => p.Name === process.env.PLAID_SECRET)?.Value;

    if (!plaidSecret) {
      throw new Error('Plaid secret not found in SSM');
    }

    const configuration = new Configuration({
      basePath: PlaidEnvironments[process.env.PLAID_ENV],
      baseOptions: {
        headers: {
          'PLAID-CLIENT-ID': process.env.PLAID_CLIENT_ID,
          'PLAID-SECRET': plaidSecret,
        },
      },
    });

    plaidClient = new PlaidApi(configuration);
    console.log('Plaid client initialized successfully');
    return plaidClient;
  } catch (error) {
    console.error('Failed to initialize Plaid client:', error);
    throw error;
  }
}

/**
 * Refresh account balances via Plaid API
 * @type {import('@types/aws-lambda').AppSyncResolverHandler}
 */
exports.handler = async (event) => {
  console.log('Event:', JSON.stringify(event, null, 2));

  try {
    await initializePlaid();

    const { userProfileID } = event.arguments;

    if (!userProfileID) {
      throw new Error('User profile ID is required');
    }

    // Get all Plaid tokens for the user
    const tokensResult = await ddbDocClient.send(new QueryCommand({
      TableName: process.env.API_YORI_PLAIDTOKENTABLE_NAME,
      IndexName: 'byUserProfile',
      KeyConditionExpression: 'userProfileID = :userID',
      FilterExpression: 'isActive = :active',
      ExpressionAttributeValues: {
        ':userID': userProfileID,
        ':active': true
      }
    }));

    const plaidTokens = tokensResult.Items || [];

    if (plaidTokens.length === 0) {
      throw new Error('No active Plaid tokens found for user');
    }

    console.log(`Found ${plaidTokens.length} Plaid tokens to refresh`);

    // Get connected accounts for the user
    const accountsResult = await ddbDocClient.send(new QueryCommand({
      TableName: process.env.API_YORI_CONNECTEDACCOUNTTABLE_NAME,
      IndexName: 'byUserProfile',
      KeyConditionExpression: 'userProfileID = :userID',
      FilterExpression: 'isActive = :active AND attribute_exists(plaidAccountID)',
      ExpressionAttributeValues: {
        ':userID': userProfileID,
        ':active': true
      }
    }));

    const connectedAccounts = accountsResult.Items || [];
    const updatedAccounts = [];

    // Group accounts by Plaid item
    const accountsByItem = {};
    connectedAccounts.forEach(account => {
      if (account.plaidItemID) {
        if (!accountsByItem[account.plaidItemID]) {
          accountsByItem[account.plaidItemID] = [];
        }
        accountsByItem[account.plaidItemID].push(account);
      }
    });

    // Refresh balances for each Plaid item
    for (const token of plaidTokens) {
      try {
        console.log(`Refreshing balances for item: ${token.itemID}`);

        // Get fresh account data from Plaid
        const accountsResponse = await plaidClient.accountsGet({
          access_token: token.accessToken,
        });

        const plaidAccounts = accountsResponse.data.accounts;

        // Update balances for connected accounts
        const itemAccounts = accountsByItem[token.itemID] || [];

        for (const connectedAccount of itemAccounts) {
          const plaidAccount = plaidAccounts.find(acc => acc.account_id === connectedAccount.plaidAccountID);

          if (plaidAccount && plaidAccount.balances.current !== null) {
            const newBalance = plaidAccount.balances.current;

            if (newBalance !== connectedAccount.balance) {
              // Update balance in DynamoDB
              await ddbDocClient.send(new UpdateCommand({
                TableName: process.env.API_YORI_CONNECTEDACCOUNTTABLE_NAME,
                Key: { id: connectedAccount.id },
                UpdateExpression: 'SET balance = :balance, lastSynced = :synced, updatedAt = :updated',
                ExpressionAttributeValues: {
                  ':balance': newBalance,
                  ':synced': new Date().toISOString(),
                  ':updated': new Date().toISOString()
                }
              }));

              connectedAccount.balance = newBalance;
              connectedAccount.lastSynced = new Date().toISOString();

              console.log(`Updated balance for ${connectedAccount.accountName}: ${newBalance}`);
            }
          }

          updatedAccounts.push(connectedAccount);
        }

        // Update token last used timestamp
        await ddbDocClient.send(new UpdateCommand({
          TableName: process.env.API_YORI_PLAIDTOKENTABLE_NAME,
          Key: { id: token.id },
          UpdateExpression: 'SET lastUsed = :used, updatedAt = :updated',
          ExpressionAttributeValues: {
            ':used': new Date().toISOString(),
            ':updated': new Date().toISOString()
          }
        }));

      } catch (error) {
        console.error(`Failed to refresh item ${token.itemID}:`, error);

        // If item is invalid, mark token as inactive
        if (error.error_code === 'ITEM_LOGIN_REQUIRED' || error.error_code === 'ACCESS_NOT_GRANTED') {
          await ddbDocClient.send(new UpdateCommand({
            TableName: process.env.API_YORI_PLAIDTOKENTABLE_NAME,
            Key: { id: token.id },
            UpdateExpression: 'SET isActive = :active, updatedAt = :updated',
            ExpressionAttributeValues: {
              ':active': false,
              ':updated': new Date().toISOString()
            }
          }));

          console.log(`Marked token ${token.id} as inactive due to Plaid error`);
        }
      }
    }

    console.log(`Refreshed ${updatedAccounts.length} accounts`);

    // Trigger financial summary recalculation if we have updates
    if (updatedAccounts.length > 0) {
      try {
        const invokeParams = {
          FunctionName: process.env.FUNCTION_CALCULATEFINANCIALSUMMARY_NAME,
          InvocationType: 'Event', // Async invocation
          Payload: JSON.stringify({
            arguments: { userProfileID },
            identity: event.identity
          })
        };

        await lambdaClient.send(new InvokeCommand(invokeParams));
        console.log('Triggered financial summary recalculation');
      } catch (error) {
        console.warn('Failed to trigger financial summary recalculation:', error);
      }
    }

    return updatedAccounts;

  } catch (error) {
    console.error('Error refreshing account balances:', error);
    throw new Error(`Failed to refresh account balances: ${error.message}`);
  }
};

const { SSMClient, GetParametersCommand } = require('@aws-sdk/client-ssm');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand, UpdateCommand } = require('@aws-sdk/lib-dynamodb');
const { PlaidApi, Configuration, PlaidEnvironments } = require('plaid');
const { v4: uuidv4 } = require('uuid');

/* Amplify Params - DO NOT EDIT
	ENV
	REGION
	API_YORI_GRAPHQLAPIIDOUTPUT
	API_YORI_GRAPHQLAPIENDPOINTOUTPUT
	API_YORI_GRAPHQLAPIKEYOUTPUT
	API_YORI_USERPROFILETABLE_NAME
	API_YORI_USERPROFILETABLE_ARN
	API_YORI_CONNECTEDACCOUNTTABLE_NAME
	API_YORI_CONNECTEDACCOUNTTABLE_ARN
	API_YORI_PLAIDTOKENTABLE_NAME
	API_YORI_PLAIDTOKENTABLE_ARN
	API_YORI_FINANCIALSUMMARYTABLE_NAME
	API_YORI_FINANCIALSUMMARYTABLE_ARN
	PLAID_CLIENT_ID
	PLAID_ENV
Amplify Params - DO NOT EDIT */

// Initialize DynamoDB client
const dynamoClient = new DynamoDBClient({ region: process.env.REGION });
const ddbDocClient = DynamoDBDocumentClient.from(dynamoClient);

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

function mapPlaidAccountType(plaidType) {
  const typeMap = {
    'checking': 'CHECKING',
    'savings': 'SAVINGS',
    'credit card': 'CREDIT_CARD',
    'investment': 'INVESTMENT',
    '401k': 'RETIREMENT',
    'ira': 'RETIREMENT',
    'mortgage': 'MORTGAGE',
    'loan': 'LOAN'
  };

  return typeMap[plaidType.toLowerCase()] || 'OTHER';
}

/**
 * Sync Plaid accounts after Link flow
 * @type {import('@types/aws-lambda').AppSyncResolverHandler}
 */
exports.handler = async (event) => {
  console.log('Event:', JSON.stringify(event, null, 2));

  try {
    await initializePlaid();

    const { publicToken, userProfileID } = event.arguments;

    if (!publicToken) {
      throw new Error('Public token is required');
    }

    if (!userProfileID) {
      throw new Error('User profile ID is required');
    }

    // Exchange public token for access token
    const exchangeResponse = await plaidClient.itemPublicTokenExchange({
      public_token: publicToken,
    });

    const accessToken = exchangeResponse.data.access_token;
    const itemId = exchangeResponse.data.item_id;

    console.log('Token exchange successful, itemId:', itemId);

    // Get account information
    const accountsResponse = await plaidClient.accountsGet({
      access_token: accessToken,
    });

    const accounts = accountsResponse.data.accounts;
    const item = accountsResponse.data.item;

    console.log(`Retrieved ${accounts.length} accounts from Plaid`);

    // Get institution info
    let institutionName = 'Unknown Institution';
    try {
      if (item.institution_id) {
        const institutionResponse = await plaidClient.institutionsGetById({
          institution_id: item.institution_id,
          country_codes: ['US'],
        });
        institutionName = institutionResponse.data.institution.name;
      }
    } catch (error) {
      console.warn('Failed to get institution name:', error.message);
    }

    // Store Plaid token
    const plaidToken = {
      id: uuidv4(),
      userProfileID: userProfileID,
      itemID: itemId,
      accessToken: accessToken, // Note: In production, encrypt this
      institutionID: item.institution_id || 'unknown',
      institutionName: institutionName,
      isActive: true,
      lastUsed: new Date().toISOString(),
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      __typename: 'PlaidToken'
    };

    await ddbDocClient.send(new PutCommand({
      TableName: process.env.API_YORI_PLAIDTOKENTABLE_NAME,
      Item: plaidToken
    }));

    console.log('Plaid token stored successfully');

    // Create connected accounts
    const connectedAccounts = [];

    for (const account of accounts) {
      const connectedAccount = {
        id: uuidv4(),
        userProfileID: userProfileID,
        accountName: account.name,
        accountType: mapPlaidAccountType(account.subtype || account.type),
        balance: account.balances.current || 0,
        institution: institutionName,
        plaidAccountID: account.account_id,
        plaidItemID: itemId,
        isActive: true,
        lastSynced: new Date().toISOString(),
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        __typename: 'ConnectedAccount'
      };

      await ddbDocClient.send(new PutCommand({
        TableName: process.env.API_YORI_CONNECTEDACCOUNTTABLE_NAME,
        Item: connectedAccount
      }));

      connectedAccounts.push(connectedAccount);
      console.log('Connected account created:', connectedAccount.accountName);
    }

    // Update user profile to indicate they have connected accounts
    await ddbDocClient.send(new UpdateCommand({
      TableName: process.env.API_YORI_USERPROFILETABLE_NAME,
      Key: { id: userProfileID },
      UpdateExpression: 'SET hasConnectedAccounts = :hasAccounts, updatedAt = :updated',
      ExpressionAttributeValues: {
        ':hasAccounts': true,
        ':updated': new Date().toISOString()
      }
    }));

    console.log('User profile updated with connected accounts flag');

    return connectedAccounts;

  } catch (error) {
    console.error('Error syncing Plaid accounts:', error);
    throw new Error(`Failed to sync Plaid accounts: ${error.message}`);
  }
};

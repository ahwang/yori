/*
Use the following code to retrieve configured secrets from SSM:

const { SSMClient, GetParametersCommand } = require('@aws-sdk/client-ssm');

const client = new SSMClient();
const { Parameters } = await client.send(new GetParametersCommand({
  Names: ["PLAID_SECRET"].map(secretName => process.env[secretName]),
  WithDecryption: true,
}));

Parameters will be of the form { Name: 'secretName', Value: 'secretValue', ... }[]
*/
const { SSMClient, GetParametersCommand } = require('@aws-sdk/client-ssm');
const { PlaidApi, Configuration, PlaidEnvironments, Products, CountryCode } = require('plaid');

/* Amplify Params - DO NOT EDIT
  ENV
  REGION
  PLAID_CLIENT_ID
  PLAID_ENV
Amplify Params - DO NOT EDIT */

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
 * Create Plaid Link token
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

    // Create link token
    const request = {
      user: {
        client_user_id: userProfileID,
      },
      client_name: 'Yori Financial',
      products: [Products.Transactions, Products.Auth],
      country_codes: [CountryCode.Us],
      language: 'en',
    };

    const createTokenResponse = await plaidClient.linkTokenCreate(request);
    const linkToken = createTokenResponse.data.link_token;

    console.log('Link token created successfully');

    return {
      linkToken: linkToken,
      expiration: createTokenResponse.data.expiration,
    };

  } catch (error) {
    console.error('Error creating link token:', error);
    throw new Error(`Failed to create link token: ${error.message}`);
  }
};

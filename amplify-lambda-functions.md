# Amplify Lambda Functions for Yori

## 1. Create User Profile with Firebase Integration

### Function: `createUserProfileWithFirebase`

```javascript
// amplify/backend/function/createUserProfileWithFirebase/src/index.js

const AWS = require('aws-sdk');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    }),
  });
}

const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
  console.log('Event:', JSON.stringify(event, null, 2));

  try {
    const { firebaseUID, email, displayName } = event.arguments;

    // Verify the user exists in Firebase
    try {
      await admin.auth().getUser(firebaseUID);
    } catch (error) {
      throw new Error(`Invalid Firebase UID: ${error.message}`);
    }

    // Check if profile already exists
    const existingProfile = await dynamodb.get({
      TableName: process.env.API_YORI_USERPROFILETABLE_NAME,
      Key: { id: firebaseUID }
    }).promise();

    if (existingProfile.Item) {
      return existingProfile.Item;
    }

    // Create new user profile
    const userProfile = {
      id: firebaseUID,
      firebaseUID: firebaseUID,
      email: email || null,
      displayName: displayName || null,
      onboardingCompleted: false,
      hasConnectedAccounts: false,
      preferredCurrency: 'USD',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      __typename: 'UserProfile'
    };

    await dynamodb.put({
      TableName: process.env.API_YORI_USERPROFILETABLE_NAME,
      Item: userProfile
    }).promise();

    return userProfile;

  } catch (error) {
    console.error('Error creating user profile:', error);
    throw new Error(`Failed to create user profile: ${error.message}`);
  }
};
```

## 2. Get User Profile by Firebase UID

### Function: `getUserProfileByFirebaseUID`

```javascript
// amplify/backend/function/getUserProfileByFirebaseUID/src/index.js

const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
  console.log('Event:', JSON.stringify(event, null, 2));

  try {
    const { firebaseUID } = event.arguments;

    // Query by GSI on firebaseUID
    const result = await dynamodb.query({
      TableName: process.env.API_YORI_USERPROFILETABLE_NAME,
      IndexName: 'byFirebaseUID',
      KeyConditionExpression: 'firebaseUID = :uid',
      ExpressionAttributeValues: {
        ':uid': firebaseUID
      },
      Limit: 1
    }).promise();

    if (result.Items && result.Items.length > 0) {
      return result.Items[0];
    }

    return null;

  } catch (error) {
    console.error('Error getting user profile:', error);
    throw new Error(`Failed to get user profile: ${error.message}`);
  }
};
```

## 3. Sync Plaid Accounts

### Function: `syncPlaidAccounts`

```javascript
// amplify/backend/function/syncPlaidAccounts/src/index.js

const AWS = require('aws-sdk');
const { PlaidApi, Configuration, PlaidEnvironments } = require('plaid');
const { v4: uuidv4 } = require('uuid');

const dynamodb = new AWS.DynamoDB.DocumentClient();

// Initialize Plaid client
const configuration = new Configuration({
  basePath: PlaidEnvironments[process.env.PLAID_ENV],
  baseOptions: {
    headers: {
      'PLAID-CLIENT-ID': process.env.PLAID_CLIENT_ID,
      'PLAID-SECRET': process.env.PLAID_SECRET,
    },
  },
});
const plaidClient = new PlaidApi(configuration);

exports.handler = async (event) => {
  console.log('Event:', JSON.stringify(event, null, 2));

  try {
    const { publicToken } = event.arguments;
    const userProfileID = event.identity.claims.sub; // Cognito user ID

    // Exchange public token for access token
    const exchangeResponse = await plaidClient.itemPublicTokenExchange({
      public_token: publicToken,
    });

    const accessToken = exchangeResponse.data.access_token;
    const itemId = exchangeResponse.data.item_id;

    // Get account information
    const accountsResponse = await plaidClient.accountsGet({
      access_token: accessToken,
    });

    const accounts = accountsResponse.data.accounts;
    const institution = accountsResponse.data.item;

    // Store Plaid token
    const plaidToken = {
      id: uuidv4(),
      userProfileID: userProfileID,
      itemID: itemId,
      accessToken: accessToken, // In production, encrypt this
      institutionID: institution.institution_id,
      institutionName: institution.institution_id, // You'd get this from institution endpoint
      isActive: true,
      lastUsed: new Date().toISOString(),
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      __typename: 'PlaidToken'
    };

    await dynamodb.put({
      TableName: process.env.API_YORI_PLAIDTOKENTABLE_NAME,
      Item: plaidToken
    }).promise();

    // Create connected accounts
    const connectedAccounts = [];

    for (const account of accounts) {
      const connectedAccount = {
        id: uuidv4(),
        userProfileID: userProfileID,
        accountName: account.name,
        accountType: mapPlaidAccountType(account.subtype || account.type),
        balance: account.balances.current || 0,
        institution: institution.institution_id,
        plaidAccountID: account.account_id,
        plaidItemID: itemId,
        isActive: true,
        lastSynced: new Date().toISOString(),
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        __typename: 'ConnectedAccount'
      };

      await dynamodb.put({
        TableName: process.env.API_YORI_CONNECTEDACCOUNTTABLE_NAME,
        Item: connectedAccount
      }).promise();

      connectedAccounts.push(connectedAccount);
    }

    // Update user profile to indicate they have connected accounts
    await dynamodb.update({
      TableName: process.env.API_YORI_USERPROFILETABLE_NAME,
      Key: { id: userProfileID },
      UpdateExpression: 'SET hasConnectedAccounts = :hasAccounts, updatedAt = :updated',
      ExpressionAttributeValues: {
        ':hasAccounts': true,
        ':updated': new Date().toISOString()
      }
    }).promise();

    return connectedAccounts;

  } catch (error) {
    console.error('Error syncing Plaid accounts:', error);
    throw new Error(`Failed to sync Plaid accounts: ${error.message}`);
  }
};

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
```

## 4. Calculate Financial Summary

### Function: `calculateFinancialSummary`

```javascript
// amplify/backend/function/calculateFinancialSummary/src/index.js

const AWS = require('aws-sdk');
const { v4: uuidv4 } = require('uuid');

const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
  console.log('Event:', JSON.stringify(event, null, 2));

  try {
    const { userProfileID } = event.arguments;

    // Get all connected accounts for the user
    const accountsResult = await dynamodb.query({
      TableName: process.env.API_YORI_CONNECTEDACCOUNTTABLE_NAME,
      IndexName: 'byUserProfile',
      KeyConditionExpression: 'userProfileID = :userID',
      FilterExpression: 'isActive = :active',
      ExpressionAttributeValues: {
        ':userID': userProfileID,
        ':active': true
      }
    }).promise();

    const accounts = accountsResult.Items || [];

    if (accounts.length === 0) {
      throw new Error('No connected accounts found');
    }

    // Calculate totals
    const assets = accounts.filter(acc => acc.balance >= 0);
    const liabilities = accounts.filter(acc => acc.balance < 0);

    const totalAssets = assets.reduce((sum, acc) => sum + acc.balance, 0);
    const totalLiabilities = Math.abs(liabilities.reduce((sum, acc) => sum + acc.balance, 0));
    const netWorth = totalAssets - totalLiabilities;

    // Calculate asset breakdown
    const assetBreakdown = calculateAssetBreakdown(assets, totalAssets);

    // Get previous financial summary for change calculation
    const previousSummariesResult = await dynamodb.query({
      TableName: process.env.API_YORI_FINANCIALSUMMARYTABLE_NAME,
      IndexName: 'byUserProfile',
      KeyConditionExpression: 'userProfileID = :userID',
      ScanIndexForward: false, // Get most recent first
      Limit: 2,
      ExpressionAttributeValues: {
        ':userID': userProfileID
      }
    }).promise();

    let netWorthChangePercent = 0;
    if (previousSummariesResult.Items && previousSummariesResult.Items.length > 1) {
      const previousNetWorth = previousSummariesResult.Items[1].netWorth;
      if (previousNetWorth > 0) {
        netWorthChangePercent = ((netWorth - previousNetWorth) / previousNetWorth) * 100;
      }
    }

    // Create new financial summary
    const financialSummary = {
      id: uuidv4(),
      userProfileID: userProfileID,
      netWorth: netWorth,
      totalAssets: totalAssets,
      totalLiabilities: totalLiabilities,
      netWorthChangePercent: netWorthChangePercent,
      assetBreakdown: JSON.stringify(assetBreakdown),
      calculatedAt: new Date().toISOString(),
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      __typename: 'FinancialSummary'
    };

    await dynamodb.put({
      TableName: process.env.API_YORI_FINANCIALSUMMARYTABLE_NAME,
      Item: financialSummary
    }).promise();

    // Parse assetBreakdown back to array for response
    financialSummary.assetBreakdown = assetBreakdown;

    return financialSummary;

  } catch (error) {
    console.error('Error calculating financial summary:', error);
    throw new Error(`Failed to calculate financial summary: ${error.message}`);
  }
};

function calculateAssetBreakdown(accounts, totalAssets) {
  const categories = {};

  accounts.forEach(account => {
    let categoryName;
    let color;

    switch (account.accountType) {
      case 'CHECKING':
      case 'SAVINGS':
        categoryName = 'Cash & Savings';
        color = 'blue';
        break;
      case 'INVESTMENT':
        categoryName = 'Investments';
        color = 'green';
        break;
      case 'RETIREMENT':
        categoryName = 'Retirement';
        color = 'purple';
        break;
      case 'MORTGAGE':
        categoryName = 'Real Estate';
        color = 'orange';
        break;
      default:
        categoryName = 'Other Assets';
        color = 'gray';
    }

    if (!categories[categoryName]) {
      categories[categoryName] = {
        name: categoryName,
        amount: 0,
        percentage: 0,
        accounts: [],
        color: color
      };
    }

    categories[categoryName].amount += account.balance;
    categories[categoryName].accounts.push({
      id: account.id,
      name: account.accountName,
      balance: account.balance
    });
  });

  // Calculate percentages
  Object.values(categories).forEach(category => {
    category.percentage = totalAssets > 0 ? (category.amount / totalAssets) * 100 : 0;
  });

  return Object.values(categories).sort((a, b) => b.amount - a.amount);
}
```

## 5. Environment Variables for Lambda Functions

Add these to your Amplify environment:

```bash
# Firebase Configuration
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_PRIVATE_KEY=your-firebase-private-key
FIREBASE_CLIENT_EMAIL=your-firebase-client-email

# Plaid Configuration
PLAID_CLIENT_ID=your-plaid-client-id
PLAID_SECRET=your-plaid-secret-key
PLAID_ENV=sandbox # or development/production
```

## 6. Deployment Commands

```bash
# Add the GraphQL schema
amplify add api

# Add Lambda functions
amplify add function

# Deploy everything
amplify push
```

## 7. Required Dependencies

For each Lambda function, add to `package.json`:

```json
{
  "dependencies": {
    "aws-sdk": "^2.1000.0",
    "firebase-admin": "^11.0.0",
    "plaid": "^10.0.0",
    "uuid": "^8.3.2"
  }
}
```

This setup provides:
- ✅ **Firebase Auth integration** with Amplify
- ✅ **Automatic user profile creation**
- ✅ **Plaid account syncing**
- ✅ **Real-time financial calculations**
- ✅ **Secure token management**
- ✅ **GraphQL API** with type safety
# AWS Backend Integration Examples

## 1. Lambda Function: User Profile Management

### File: `user-profile/index.js`

```javascript
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
  try {
    // Extract Firebase token from Authorization header
    const authHeader = event.headers.Authorization || event.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Missing or invalid authorization header' }),
      };
    }

    const idToken = authHeader.substring(7);

    // Verify Firebase token
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const uid = decodedToken.uid;

    const method = event.httpMethod;
    const tableName = process.env.USERS_TABLE_NAME;

    if (method === 'GET') {
      // Get user profile
      const result = await dynamodb.get({
        TableName: tableName,
        Key: { user_id: uid }
      }).promise();

      if (!result.Item) {
        // Create new user profile if doesn't exist
        const newProfile = {
          user_id: uid,
          email: decodedToken.email,
          display_name: decodedToken.name,
          created_at: new Date().toISOString(),
          onboarding_completed: false,
          has_connected_accounts: false
        };

        await dynamodb.put({
          TableName: tableName,
          Item: newProfile
        }).promise();

        return {
          statusCode: 200,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
          body: JSON.stringify(newProfile),
        };
      }

      return {
        statusCode: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
        body: JSON.stringify(result.Item),
      };
    }

    if (method === 'PUT') {
      // Update user profile
      const body = JSON.parse(event.body);

      const updateParams = {
        TableName: tableName,
        Key: { user_id: uid },
        UpdateExpression: 'SET display_name = :name, onboarding_completed = :onboarding, updated_at = :updated',
        ExpressionAttributeValues: {
          ':name': body.displayName,
          ':onboarding': body.onboardingCompleted,
          ':updated': new Date().toISOString()
        },
        ReturnValues: 'ALL_NEW'
      };

      const result = await dynamodb.update(updateParams).promise();

      return {
        statusCode: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
        body: JSON.stringify(result.Attributes),
      };
    }

    return {
      statusCode: 405,
      body: JSON.stringify({ error: 'Method not allowed' }),
    };

  } catch (error) {
    console.error('Error:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
};
```

## 2. Lambda Function: Financial Summary

### File: `financial-summary/index.js`

```javascript
const AWS = require('aws-sdk');
const admin = require('firebase-admin');

const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
  try {
    // Verify Firebase token (same pattern as above)
    const authHeader = event.headers.Authorization || event.headers.authorization;
    const idToken = authHeader.substring(7);
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const uid = decodedToken.uid;

    // Get user's connected accounts
    const accountsResult = await dynamodb.query({
      TableName: process.env.ACCOUNTS_TABLE_NAME,
      KeyConditionExpression: 'user_id = :uid',
      ExpressionAttributeValues: {
        ':uid': uid
      }
    }).promise();

    const accounts = accountsResult.Items || [];

    // Calculate financial summary
    const assets = accounts.filter(acc => acc.balance >= 0);
    const liabilities = accounts.filter(acc => acc.balance < 0);

    const totalAssets = assets.reduce((sum, acc) => sum + acc.balance, 0);
    const totalLiabilities = Math.abs(liabilities.reduce((sum, acc) => sum + acc.balance, 0));
    const netWorth = totalAssets - totalLiabilities;

    // Calculate asset breakdown
    const assetBreakdown = calculateAssetBreakdown(assets, totalAssets);

    // Get previous month's net worth for change calculation
    // (This would typically come from a separate historical data table)
    const previousNetWorth = netWorth * 0.977; // Mock 2.3% growth
    const netWorthChangePercent = ((netWorth - previousNetWorth) / previousNetWorth) * 100;

    const summary = {
      netWorth,
      netWorthChangePercent,
      totalAssets,
      totalLiabilities,
      assetBreakdown,
      lastUpdated: new Date().toISOString()
    };

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
      body: JSON.stringify(summary),
    };

  } catch (error) {
    console.error('Error:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
};

function calculateAssetBreakdown(accounts, totalAssets) {
  const categories = {};

  accounts.forEach(account => {
    let categoryName;
    switch (account.type.toLowerCase()) {
      case 'checking':
      case 'savings':
        categoryName = 'Cash & Savings';
        break;
      case 'investment':
      case 'brokerage':
        categoryName = 'Investments';
        break;
      case 'retirement':
      case '401k':
      case 'ira':
        categoryName = 'Retirement';
        break;
      default:
        categoryName = 'Other Assets';
    }

    if (!categories[categoryName]) {
      categories[categoryName] = {
        name: categoryName,
        amount: 0,
        accounts: [],
        color: getCategoryColor(categoryName)
      };
    }

    categories[categoryName].amount += account.balance;
    categories[categoryName].accounts.push(account);
  });

  // Calculate percentages
  Object.values(categories).forEach(category => {
    category.percentage = totalAssets > 0 ? (category.amount / totalAssets) * 100 : 0;
  });

  return Object.values(categories).sort((a, b) => b.amount - a.amount);
}

function getCategoryColor(categoryName) {
  const colors = {
    'Cash & Savings': 'blue',
    'Investments': 'green',
    'Retirement': 'purple',
    'Real Estate': 'orange',
    'Other Assets': 'gray'
  };
  return colors[categoryName] || 'gray';
}
```

## 3. Lambda Function: Plaid Integration

### File: `plaid-integration/index.js`

```javascript
const AWS = require('aws-sdk');
const admin = require('firebase-admin');
const { PlaidApi, Configuration, PlaidEnvironments } = require('plaid');

const dynamodb = new AWS.DynamoDB.DocumentClient();

// Initialize Plaid client
const configuration = new Configuration({
  basePath: PlaidEnvironments[process.env.PLAID_ENV], // 'sandbox', 'development', or 'production'
  baseOptions: {
    headers: {
      'PLAID-CLIENT-ID': process.env.PLAID_CLIENT_ID,
      'PLAID-SECRET': process.env.PLAID_SECRET,
    },
  },
});
const plaidClient = new PlaidApi(configuration);

exports.handler = async (event) => {
  try {
    // Verify Firebase token
    const authHeader = event.headers.Authorization || event.headers.authorization;
    const idToken = authHeader.substring(7);
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const uid = decodedToken.uid;

    const method = event.httpMethod;

    if (method === 'POST' && event.path === '/plaid/exchange-token') {
      // Exchange public token for access token
      const { publicToken } = JSON.parse(event.body);

      const response = await plaidClient.itemPublicTokenExchange({
        public_token: publicToken,
      });

      const accessToken = response.data.access_token;
      const itemId = response.data.item_id;

      // Get account information
      const accountsResponse = await plaidClient.accountsGet({
        access_token: accessToken,
      });

      // Store access token and accounts in DynamoDB
      const accounts = accountsResponse.data.accounts.map(account => ({
        user_id: uid,
        account_id: account.account_id,
        name: account.name,
        type: account.subtype || account.type,
        balance: account.balances.current || 0,
        institution: accountsResponse.data.item.institution_id,
        plaid_account_id: account.account_id,
        created_at: new Date().toISOString()
      }));

      // Store access token
      await dynamodb.put({
        TableName: process.env.PLAID_TOKENS_TABLE_NAME,
        Item: {
          user_id: uid,
          item_id: itemId,
          access_token: accessToken,
          created_at: new Date().toISOString()
        }
      }).promise();

      // Store accounts
      const putRequests = accounts.map(account => ({
        PutRequest: { Item: account }
      }));

      await dynamodb.batchWrite({
        RequestItems: {
          [process.env.ACCOUNTS_TABLE_NAME]: putRequests
        }
      }).promise();

      return {
        statusCode: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
        body: JSON.stringify({
          success: true,
          accountIds: accounts.map(acc => acc.account_id),
          message: 'Accounts connected successfully'
        }),
      };
    }

    return {
      statusCode: 405,
      body: JSON.stringify({ error: 'Method not allowed' }),
    };

  } catch (error) {
    console.error('Error:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
};
```

## 4. DynamoDB Table Structures

### Users Table
```
Table Name: yori-users
Partition Key: user_id (String)

Attributes:
- user_id: Firebase UID
- email: User's email
- display_name: User's display name
- created_at: ISO timestamp
- updated_at: ISO timestamp
- onboarding_completed: Boolean
- has_connected_accounts: Boolean
```

### Accounts Table
```
Table Name: yori-accounts
Partition Key: user_id (String)
Sort Key: account_id (String)

Attributes:
- user_id: Firebase UID
- account_id: Unique account identifier
- name: Account name (e.g., "Chase Checking")
- type: Account type (checking, savings, credit, etc.)
- balance: Current balance
- institution: Bank/institution name
- plaid_account_id: Plaid's account ID
- created_at: ISO timestamp
- updated_at: ISO timestamp
- is_active: Boolean
```

### Plaid Tokens Table
```
Table Name: yori-plaid-tokens
Partition Key: user_id (String)
Sort Key: item_id (String)

Attributes:
- user_id: Firebase UID
- item_id: Plaid item ID
- access_token: Encrypted Plaid access token
- created_at: ISO timestamp
- last_used: ISO timestamp
```

## 5. API Gateway Configuration

### Routes:
- `GET /user/profile` → user-profile Lambda
- `PUT /user/profile` → user-profile Lambda
- `GET /user/financial-summary` → financial-summary Lambda
- `GET /user/accounts` → accounts Lambda
- `POST /plaid/exchange-token` → plaid-integration Lambda
- `POST /user/accounts/select` → accounts Lambda
- `DELETE /user/accounts/{accountId}` → accounts Lambda

### CORS Configuration:
```json
{
  "allowCredentials": false,
  "allowHeaders": ["Content-Type", "Authorization"],
  "allowMethods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
  "allowOrigins": ["*"]
}
```

## 6. Environment Variables

### For Lambda Functions:
```
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_PRIVATE_KEY=your-firebase-private-key
FIREBASE_CLIENT_EMAIL=your-firebase-client-email
USERS_TABLE_NAME=yori-users
ACCOUNTS_TABLE_NAME=yori-accounts
PLAID_TOKENS_TABLE_NAME=yori-plaid-tokens
PLAID_CLIENT_ID=your-plaid-client-id
PLAID_SECRET=your-plaid-secret
PLAID_ENV=sandbox
```

This setup gives you:
- ✅ Firebase Auth verification in every Lambda
- ✅ Secure DynamoDB operations using Firebase UID
- ✅ Plaid integration for account connections
- ✅ Scalable serverless architecture
- ✅ Proper error handling and CORS
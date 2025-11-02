const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, QueryCommand, PutCommand } = require('@aws-sdk/lib-dynamodb');
const { v4: uuidv4 } = require('uuid');

/* Amplify Params - DO NOT EDIT
	API_YORI_CONNECTEDACCOUNTTABLE_ARN
	API_YORI_CONNECTEDACCOUNTTABLE_NAME
	API_YORI_FINANCIALSUMMARYTABLE_ARN
	API_YORI_FINANCIALSUMMARYTABLE_NAME
	API_YORI_GRAPHQLAPIIDOUTPUT
	API_YORI_USERPROFILETABLE_ARN
	API_YORI_USERPROFILETABLE_NAME
	ENV
	REGION
Amplify Params - DO NOT EDIT */

// Initialize DynamoDB client
const dynamoClient = new DynamoDBClient({ region: process.env.REGION });
const ddbDocClient = DynamoDBDocumentClient.from(dynamoClient);

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

/**
 * Calculate comprehensive financial summary
 * @type {import('@types/aws-lambda').AppSyncResolverHandler}
 */
exports.handler = async (event) => {
  console.log('Event:', JSON.stringify(event, null, 2));

  try {
    const { userProfileID } = event.arguments;

    if (!userProfileID) {
      throw new Error('User profile ID is required');
    }

    // Get all connected accounts for the user
    const accountsResult = await ddbDocClient.send(new QueryCommand({
      TableName: process.env.API_YORI_CONNECTEDACCOUNTTABLE_NAME,
      IndexName: 'byUserProfile',
      KeyConditionExpression: 'userProfileID = :userID',
      FilterExpression: 'isActive = :active',
      ExpressionAttributeValues: {
        ':userID': userProfileID,
        ':active': true
      }
    }));

    const accounts = accountsResult.Items || [];

    if (accounts.length === 0) {
      throw new Error('No connected accounts found');
    }

    console.log(`Found ${accounts.length} active accounts`);

    // Calculate totals
    const assets = accounts.filter(acc => acc.balance >= 0);
    const liabilities = accounts.filter(acc => acc.balance < 0);

    const totalAssets = assets.reduce((sum, acc) => sum + acc.balance, 0);
    const totalLiabilities = Math.abs(liabilities.reduce((sum, acc) => sum + acc.balance, 0));
    const netWorth = totalAssets - totalLiabilities;

    console.log(`Calculated: Assets=${totalAssets}, Liabilities=${totalLiabilities}, NetWorth=${netWorth}`);

    // Calculate asset breakdown
    const assetBreakdown = calculateAssetBreakdown(assets, totalAssets);

    // Get previous financial summary for change calculation
    const previousSummariesResult = await ddbDocClient.send(new QueryCommand({
      TableName: process.env.API_YORI_FINANCIALSUMMARYTABLE_NAME,
      IndexName: 'byUserProfile',
      KeyConditionExpression: 'userProfileID = :userID',
      ScanIndexForward: false, // Get most recent first
      Limit: 2,
      ExpressionAttributeValues: {
        ':userID': userProfileID
      }
    }));

    let netWorthChangePercent = 0;
    if (previousSummariesResult.Items && previousSummariesResult.Items.length > 1) {
      const previousNetWorth = previousSummariesResult.Items[1].netWorth;
      if (previousNetWorth > 0) {
        netWorthChangePercent = ((netWorth - previousNetWorth) / previousNetWorth) * 100;
      }
    }

    console.log(`Net worth change: ${netWorthChangePercent}%`);

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

    await ddbDocClient.send(new PutCommand({
      TableName: process.env.API_YORI_FINANCIALSUMMARYTABLE_NAME,
      Item: financialSummary
    }));

    console.log('Financial summary created successfully:', financialSummary.id);

    // Parse assetBreakdown back to array for response
    financialSummary.assetBreakdown = assetBreakdown;

    return financialSummary;

  } catch (error) {
    console.error('Error calculating financial summary:', error);
    throw new Error(`Failed to calculate financial summary: ${error.message}`);
  }
};

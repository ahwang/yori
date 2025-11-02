const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, QueryCommand } = require('@aws-sdk/lib-dynamodb');

/* Amplify Params - DO NOT EDIT
	ENV
	REGION
	API_YORI_CONNECTEDACCOUNTTABLE_NAME
	API_YORI_CONNECTEDACCOUNTTABLE_ARN
Amplify Params - DO NOT EDIT */

// Initialize DynamoDB client
const dynamoClient = new DynamoDBClient({ region: process.env.REGION });
const ddbDocClient = DynamoDBDocumentClient.from(dynamoClient);

/**
 * Get active connected accounts for user
 * @type {import('@types/aws-lambda').AppSyncResolverHandler}
 */
exports.handler = async (event) => {
  console.log('Event:', JSON.stringify(event, null, 2));

  try {
    const { userProfileID } = event.arguments;

    if (!userProfileID) {
      throw new Error('User profile ID is required');
    }

    // Get all active connected accounts for the user
    const result = await ddbDocClient.send(new QueryCommand({
      TableName: process.env.API_YORI_CONNECTEDACCOUNTTABLE_NAME,
      IndexName: 'byUserProfile',
      KeyConditionExpression: 'userProfileID = :userID',
      FilterExpression: 'isActive = :active',
      ExpressionAttributeValues: {
        ':userID': userProfileID,
        ':active': true
      }
    }));

    const accounts = result.Items || [];

    console.log(`Found ${accounts.length} active connected accounts for user`);

    return accounts;

  } catch (error) {
    console.error('Error getting active connected accounts:', error);
    throw new Error(`Failed to get active connected accounts: ${error.message}`);
  }
};
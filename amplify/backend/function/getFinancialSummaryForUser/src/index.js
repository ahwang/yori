const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, QueryCommand } = require('@aws-sdk/lib-dynamodb');

/* Amplify Params - DO NOT EDIT
	ENV
	REGION
	API_YORI_FINANCIALSUMMARYTABLE_NAME
	API_YORI_FINANCIALSUMMARYTABLE_ARN
Amplify Params - DO NOT EDIT */

// Initialize DynamoDB client
const dynamoClient = new DynamoDBClient({ region: process.env.REGION });
const ddbDocClient = DynamoDBDocumentClient.from(dynamoClient);

/**
 * Get latest financial summary for user
 * @type {import('@types/aws-lambda').AppSyncResolverHandler}
 */
exports.handler = async (event) => {
  console.log('Event:', JSON.stringify(event, null, 2));

  try {
    const { userProfileID } = event.arguments;

    if (!userProfileID) {
      throw new Error('User profile ID is required');
    }

    // Get the most recent financial summary for the user
    const result = await ddbDocClient.send(new QueryCommand({
      TableName: process.env.API_YORI_FINANCIALSUMMARYTABLE_NAME,
      IndexName: 'byUserProfile',
      KeyConditionExpression: 'userProfileID = :userID',
      ScanIndexForward: false, // Get most recent first
      Limit: 1,
      ExpressionAttributeValues: {
        ':userID': userProfileID
      }
    }));

    if (result.Items && result.Items.length > 0) {
      const summary = result.Items[0];

      // Parse assetBreakdown from JSON string to array
      if (summary.assetBreakdown && typeof summary.assetBreakdown === 'string') {
        try {
          summary.assetBreakdown = JSON.parse(summary.assetBreakdown);
        } catch (error) {
          console.warn('Failed to parse assetBreakdown JSON:', error);
          summary.assetBreakdown = [];
        }
      }

      console.log('Financial summary found:', summary.id);
      return summary;
    }

    console.log('No financial summary found for user:', userProfileID);
    return null;

  } catch (error) {
    console.error('Error getting financial summary:', error);
    throw new Error(`Failed to get financial summary: ${error.message}`);
  }
};
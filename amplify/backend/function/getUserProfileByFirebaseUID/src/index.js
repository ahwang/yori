/*
Use the following code to retrieve configured secrets from SSM:

const { SSMClient, GetParametersCommand } = require('@aws-sdk/client-ssm');

const client = new SSMClient();
const { Parameters } = await client.send(new GetParametersCommand({
  Names: ["FIREBASE_PRIVATE_KEY"].map(secretName => process.env[secretName]),
  WithDecryption: true,
}));

Parameters will be of the form { Name: 'secretName', Value: 'secretValue', ... }[]
*/
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, QueryCommand } = require('@aws-sdk/lib-dynamodb');

/* Amplify Params - DO NOT EDIT
	API_YORI_GRAPHQLAPIIDOUTPUT
	API_YORI_USERPROFILETABLE_ARN
	API_YORI_USERPROFILETABLE_NAME
	ENV
	REGION
Amplify Params - DO NOT EDIT */

// Initialize DynamoDB client
const dynamoClient = new DynamoDBClient({ region: process.env.REGION });
const ddbDocClient = DynamoDBDocumentClient.from(dynamoClient);

/**
 * Get user profile by Firebase UID using GSI
 * @type {import('@types/aws-lambda').AppSyncResolverHandler}
 */
exports.handler = async (event) => {
  console.log('Event:', JSON.stringify(event, null, 2));

  try {
    const { firebaseUID } = event.arguments;

    if (!firebaseUID) {
      throw new Error('Firebase UID is required');
    }

    // Query by GSI on firebaseUID
    const result = await ddbDocClient.send(new QueryCommand({
      TableName: process.env.API_YORI_USERPROFILETABLE_NAME,
      IndexName: 'byFirebaseUID',
      KeyConditionExpression: 'firebaseUID = :uid',
      ExpressionAttributeValues: {
        ':uid': firebaseUID
      },
      Limit: 1
    }));

    if (result.Items && result.Items.length > 0) {
      console.log('User profile found:', result.Items[0].id);
      return result.Items[0];
    }

    console.log('User profile not found for firebaseUID:', firebaseUID);
    return null;

  } catch (error) {
    console.error('Error getting user profile:', error);
    throw new Error(`Failed to get user profile: ${error.message}`);
  }
};

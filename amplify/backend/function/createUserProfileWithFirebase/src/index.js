/*
Use the following code to retrieve configured secrets from SSM:

const { SSMClient, GetParametersCommand } = require('@aws-sdk/client-ssm');

const client = new SSMClient();
const { Parameters } = await client.send(new GetParametersCommand({
  Names: ["FIREBASE_PRIVATE_KEY","PLAID_SECRET"].map(secretName => process.env[secretName]),
  WithDecryption: true,
}));

Parameters will be of the form { Name: 'secretName', Value: 'secretValue', ... }[]
*/
const { SSMClient, GetParametersCommand } = require('@aws-sdk/client-ssm');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand, GetCommand } = require('@aws-sdk/lib-dynamodb');
const admin = require('firebase-admin');

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

// Initialize Firebase Admin (only once)
let firebaseInitialized = false;

async function initializeFirebase() {
  if (firebaseInitialized) return;

  try {
    // Get Firebase secrets from SSM
    const ssmClient = new SSMClient({ region: process.env.REGION });
    const { Parameters } = await ssmClient.send(new GetParametersCommand({
      Names: [process.env.FIREBASE_PRIVATE_KEY].filter(Boolean),
      WithDecryption: true,
    }));

    let privateKey = Parameters.find(p => p.Name === process.env.FIREBASE_PRIVATE_KEY)?.Value;

    if (!privateKey) {
      throw new Error('Firebase private key not found in secrets');
    }

    privateKey = privateKey.trim();
    if ( (privateKey.startsWith('"') && (privateKey.endsWith('"'))) || (privateKey.startsWith("'") && (privateKey.endsWith("'"))) ) {
      privateKey = privateKey.slice(1, -1);
    } 
    privateKey = privateKey.replace(/\\n/g, '\n');
    privateKey = privateKey.trim();

    // Initialize Firebase Admin SDK
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        privateKey: privateKey.replace(/\\n/g, '\n'),
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      }),
    });

    firebaseInitialized = true;
    console.log('Firebase Admin initialized successfully');
  } catch (error) {
    console.error('Failed to initialize Firebase Admin:', error);
    throw error;
  }
}

/**
 * Creates a user profile with Firebase UID verification
 * @type {import('@types/aws-lambda').AppSyncResolverHandler}
 */
exports.handler = async (event) => {
  console.log('Event:', JSON.stringify(event, null, 2));

  try {
    await initializeFirebase();

    const { firebaseUID, email, displayName } = event.arguments;

    if (!firebaseUID) {
      throw new Error('Firebase UID is required');
    }

    // Verify the user exists in Firebase
    try {
      await admin.auth().getUser(firebaseUID);
      console.log(`Firebase user verified: ${firebaseUID}`);
    } catch (error) {
      console.error('Firebase verification failed:', error);
      throw new Error(`Invalid Firebase UID: ${error.message}`);
    }

    // Check if profile already exists
    const existingProfile = await ddbDocClient.send(new GetCommand({
      TableName: process.env.API_YORI_USERPROFILETABLE_NAME,
      Key: { id: firebaseUID }
    }));

    if (existingProfile.Item) {
      console.log('User profile already exists');
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

    await ddbDocClient.send(new PutCommand({
      TableName: process.env.API_YORI_USERPROFILETABLE_NAME,
      Item: userProfile
    }));

    console.log('User profile created successfully:', userProfile.id);
    return userProfile;

  } catch (error) {
    console.error('Error creating user profile:', error);
    throw new Error(`Failed to create user profile: ${error.message}`);
  }
};

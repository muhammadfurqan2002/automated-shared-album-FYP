const AWS = require('aws-sdk');
require('dotenv').config();
const {queueDuplicateReport}=require('./duplicateNotificationService')
const {queueBlurReport}=require('./blurNotificationService')

AWS.config.update({
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  region: process.env.AWS_REGION,
});


const s3 = new AWS.S3();
const lambda=new AWS.Lambda();



async function invokeSingleFaceRegistration(eventPayload) {
  const params = {
    // FunctionName: 'face_registration',
    FunctionName: '',
    InvocationType: 'RequestResponse',
    Payload: JSON.stringify(eventPayload),
  };

  try {
    const response = await lambda.invoke(params).promise();
    const payload = JSON.parse(response.Payload);
    const body = typeof payload.body === "string" ? JSON.parse(payload.body) : payload.body;

    return body;
  } catch (err) {
    // console.error('Error invoking Single_Face_Registration:', err);
    console.error('Error invoking triple-side-face-registration:', err);
    throw err;
  }
}

async function generateProfileImageUrl(fileName, fileType, userId) {
  const bucketName = process.env.AWS_BUCKET_NAME;
  // const fileKey = `users/${userId}/${Date.now()}-${fileName}`;
  const fileKey = `users/${userId}/${fileName}`;
  const s3Params = {
    Bucket: bucketName,
    Key: fileKey,
    Expires: 300,
    ContentType: fileType,
  };

  const uploadURL = await s3.getSignedUrlPromise('putObject', s3Params);
  const s3ImageUrl = `https://${bucketName}.s3.amazonaws.com/${fileKey}`;
  return { s3ImageUrl, uploadURL };
}

async function generateAlbumCoverUrl(fileName, fileType, userId) {
  const bucketName = process.env.AWS_BUCKET_NAME;
  const fileKey = `album-covers/${userId}/${Date.now()}-${fileName}`;
  const s3Params = {
    Bucket: bucketName,
    Key: fileKey,
    Expires: 300,
    ContentType: fileType,
  };

  const uploadURL = await s3.getSignedUrlPromise('putObject', s3Params);
  const s3ImageUrl = `https://${bucketName}.s3.amazonaws.com/${fileKey}`;
  return { s3ImageUrl, uploadURL };
}

async function generateImageUploadUrl(fileName, fileType, albumId, userId) {
  const bucketName = process.env.AWS_BUCKET_NAME;
  const fileKey = `images/${albumId}/${userId}/${Date.now()}-${fileName}`;
  const s3Params = {
    Bucket: bucketName,
    Key: fileKey,
    Expires: 300,
    ContentType: fileType,
  };

  const uploadURL = await s3.getSignedUrlPromise('putObject', s3Params);
  console.log(uploadURL,"uploadURL");
  const s3ImageUrl = `https://${bucketName}.s3.amazonaws.com/${fileKey}`;
  return { s3ImageUrl, uploadURL,fileKey };
}

const checkFileExists = async (bucket, key) => {
  try {
    await s3.headObject({ Bucket: bucket, Key: key }).promise();
    return true;
  } catch (err) {
    if (err.code === 'NotFound') return false;
    console.error(`S3 file check error for ${bucket}/${key}:`, err);
    throw err;
  }
};


const calculateBackoff = (attempt) => {
  return Math.pow(2, attempt) * 1000;
};


const notifyBatchFaceRecognitionService = async (aggregatedEvent) => {
  const maxAttempts = 2;
  let attempt = 0;

  while (attempt < maxAttempts) {
    try {
      console.log(
        attempt === 0
          ? "First pass for batch Lambda invocation..."
          : "Second pass for batch Lambda invocation..."
      );

      const params = {
        FunctionName: process.env.FACE_RECOGNITION_LAMBDA,
        InvocationType: 'RequestResponse',
        Payload: JSON.stringify(aggregatedEvent)
      };

      const response = await lambda.invoke(params).promise();

      if (!response.Payload) {
        throw new Error('Lambda returned empty payload');
      }

      const data = JSON.parse(response.Payload);
      if (!data || !data.body) {
        throw new Error('Invalid Lambda response structure');
      }

      console.log(`Lambda response (attempt ${attempt + 1}):`, data);
      return data;
    } catch (error) {
      console.error(`Error on Lambda invocation (attempt ${attempt + 1}):`, error);
      attempt++;
      if (attempt < maxAttempts) {
        const backoffDelay = calculateBackoff(attempt);
        console.log(`Retrying Lambda invocation in ${backoffDelay/1000} seconds...`);
        await new Promise(resolve => setTimeout(resolve, backoffDelay));
      } else {
        throw error;
      }
    }
  }
};





// Updated notifyBlurService to use queue
const notifyBlurService = async (aggregatedEvent) => {
  const params = {
    FunctionName:   process.env.BLUR_DETECTION_LAMBDA,
    InvocationType: 'RequestResponse',
    Payload:        JSON.stringify(aggregatedEvent),
  };
  
  const response = await lambda.invoke(params).promise();
  console.log("Blur detection response:", response);
  
  try {
    const envelope = typeof response.Payload === 'string'
      ? JSON.parse(response.Payload)
      : response.Payload;
    
    const countsByAlbum = JSON.parse(envelope.body);
    
    console.log(countsByAlbum);
    
    for (const albumIdStr of Object.keys(countsByAlbum)) {
      const albumId = Number(albumIdStr);
      console.log(albumId);
      if (!isNaN(albumId)) {
        console.log(`Queuing blur report for album ${albumId}`);
        await queueBlurReport(albumId, 60 * 1000); 
      }
    }
  } catch (err) {
    console.error("Failed to decode blur payload or queue report:", err);
  }
};

const notifyDuplicateService = async (aggregatedEvent) => {
  const params = {
    FunctionName:   process.env.DUPLICATE_DETECTION_LAMBDA,
    InvocationType: 'RequestResponse',
    Payload:        JSON.stringify(aggregatedEvent),
  };
  
  const response = await lambda.invoke(params).promise();
  console.log("raw Lambda response:", response);
  
  try {
    const envelope = typeof response.Payload === 'string'
      ? JSON.parse(response.Payload)
      : response.Payload;
    
    const body = JSON.parse(envelope.body);
    
    console.log("lambda duplicate response after decode");
    console.log(body);
    
    const albumId = Number(body.album_id);
    if (!albumId) {
      console.warn("No album_id in Lambda response; skipping report");
      return;
    }
    
    if(Number(body.total_duplicates)==0){
      return;
    }
    
    await queueDuplicateReport(albumId,60*1000);
  } catch (err) {
    console.error("Failed to decode Lambda payload or queue report:", err);
  }
};




const uploadToS3 = async (file) => {

  if (!file || !file.buffer) {
    console.error('S3 Upload Error: No file buffer received');
    throw new Error('File upload failed: No file buffer');
  }

  const params = {
    Bucket: process.env.AWS_BUCKET_NAME,
    Key: `profile-images/${Date.now()}_${file.originalname}`,
    Body: file.buffer,
    ContentType: file.mimetype,
  };

  try {
    console.log('Uploading to S3:', params.Key);
    const uploadResult = await s3.upload(params).promise();
    console.log('S3 Upload Success:', uploadResult.Location);
    return uploadResult.Location;
  } catch (error) {
    console.error('S3 Upload Error:', error);
    throw new Error('File upload failed');
  }
};

async function deleteFromS3(s3Key) {
  try {
    const data = await s3.deleteObject({
      Bucket: process.env.AWS_BUCKET_NAME,
      Key: s3Key,
    }).promise();

    console.log('S3 delete success:', data);
    return data;
  } catch (error) {
    console.error('S3 delete error:', error);
    throw error;
  }
}

module.exports = {notifyDuplicateService,notifyBlurService ,invokeSingleFaceRegistration,generateProfileImageUrl,uploadToS3,generateAlbumCoverUrl,generateImageUploadUrl,deleteFromS3,checkFileExists,notifyBatchFaceRecognitionService,s3 };

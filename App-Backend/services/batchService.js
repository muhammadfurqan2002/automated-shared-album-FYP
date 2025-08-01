const Queue = require("bull");
const { createClient } = require("redis");
const {
  checkFileExists,
  notifyBatchFaceRecognitionService,
  notifyBlurService,
  notifyDuplicateService,
} = require("./s3Service");
const {queueFaceRecognitionReport}=require('./faceNotificationService')
require("dotenv").config();

const batchQueue = new Queue("batch-processing", process.env.REDIS_URL, {
  defaultJobOptions: {
    attempts: 3,
    backoff: { type: "exponential", delay: 5000 },
  },
});


const storeRecognitionResults = async (albumId, result) => {
  const redisClient = createClient({ url: process.env.REDIS_URL });

  try {
    await redisClient.connect();

    const userId = result.user_id;
    if (!userId) {
      console.error("Missing user_id in result:", result);
      return;
    }

    const uniqueKey = `face-recognition-results:${albumId}:${userId}`;

    // ✅ NEW LOGIC: check existing result and compare distances
    const existing = await redisClient.get(uniqueKey);

    if (existing) {
      const existingResult = JSON.parse(existing);

      if (result.distance >= existingResult.distance) {
        console.log(`Existing match for ${uniqueKey} is better or equal, skipping.`);
        return;
      }

      console.log(`New result for ${uniqueKey} is better. Updating Redis.`);
    }

    const serializedResult = JSON.stringify({
      albumId,
      ...result,
      processedAt: new Date().toISOString(),
    });

    console.log(`Storing Redis key: ${uniqueKey}`);
    await redisClient.set(uniqueKey, serializedResult, { EX: 24 * 60 * 60 }); // expires in 24 hours
    console.log(`Successfully stored recognition result for ${uniqueKey}`);
  } catch (error) {
    console.error("Error storing recognition result in Redis:", error);
  } finally {
    await redisClient.quit();
  }
};
batchQueue.process(5, async (job) => {
  const records = job.data.records;
  console.log(`Processing batch job with ${records.length} record(s)`);

  const availableRecords = [];
  for (const record of records) {
    if (
      await checkFileExists(process.env.AWS_BUCKET_NAME, record.s3.object.key)
    ) {
      availableRecords.push(record);
    } else {
      console.log(`File ${record.s3.object.key} not available yet, skipping.`);
    }
  }

  if (availableRecords.length > 0) {
    const aggregatedEvent = { Records: availableRecords };

    fireAndForgetBlur(aggregatedEvent);
    fireAndForgetDuplicate(aggregatedEvent);

    const data = await notifyBatchFaceRecognitionService(aggregatedEvent);

    // console.log("Lambda invocation successful:", data);

    if (data && data.body) {
      try {
        const parsedBody = JSON.parse(data.body);
        const results = Array.isArray(parsedBody)
          ? parsedBody
          : parsedBody.results;
          let album_Id=null;
        for (const result of results) {
          const albumId =
            result.album_id || (result.key && result.key.split("/")[1]);
            album_Id=albumId;
            if (!albumId) {
            console.error("Album id not found in result:", result);
            continue;
          }
          await storeRecognitionResults(albumId, result);

        }
        if (album_Id) {
          queueFaceRecognitionReport(album_Id, 60 * 1000).catch((err) =>
            console.error(`Failed to queue face recognition report for album ${album_Id}:`, err)
          );
        }
      } catch (parseError) {
        console.error("Error parsing Lambda response:", parseError);
      }
    }
    return data;
  } else {
    console.log("No records available for processing in this job.");
    throw new Error("No available records.");
  }
});

const enqueueBatch = async (records) => {
  await batchQueue.add({ records });
};

const getRecognitionResults = async (albumId) => {
  const redisClient = createClient({ url: process.env.REDIS_URL });

  try {
    await redisClient.connect();
    const pattern = `face-recognition-results:${albumId}:*`;
    const keys = await redisClient.keys(pattern);
    const results = [];
    for (const key of keys) {
      const result = await redisClient.get(key);
      if (result) {
        try {
          results.push(JSON.parse(result));
        } catch (parseError) {
          console.error("Error parsing Redis result:", parseError);
        }
      }
    }
    console.log(
      `Retrieved ${results.length} recognition results for album ${albumId}`
    );
    return results;
  } catch (error) {
    console.error("Error in getRecognitionResults:", error);
    return [];
  } finally {
    await redisClient.quit();
  }
};

function fireAndForgetBlur(aggregatedEvent) {
  (async () => {
    try {
      await notifyBlurService(aggregatedEvent);
    } catch (err) {
      console.error("Blur Lambda failed:", err);
    }
  })();
}

function fireAndForgetDuplicate(aggregatedEvent) {
  (async () => {
    try {
      await notifyDuplicateService(aggregatedEvent);
      
    } catch (err) {
      console.error("Duplicate Lambda failed:", err);
    }
  })();
}

module.exports = {
  enqueueBatch,
  getRecognitionResults,
  batchQueue,
  storeRecognitionResults,
};

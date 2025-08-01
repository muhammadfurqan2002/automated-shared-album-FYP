// services/geminiService.js
const axios = require("axios");

const API_KEY = "";
// const MODEL_NAME = 'gemini-1.5-flash';
const MODEL_NAME = 'gemini-2.0-flash';
// const API_URL = `https://generativelanguage.googleapis.com/v1/models/${MODEL_NAME}:generateContent?key=${API_KEY}`;


const imageUrlToBase64 = async (url, maxRetries = 3) => {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      console.log(`Attempting to fetch image (attempt ${attempt}/${maxRetries}): ${url}`);

      const response = await axios.get(url, {
        responseType: 'arraybuffer',
        timeout: 30000,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'image/*,*/*;q=0.8'
        },
        maxContentLength: 50 * 1024 * 1024,
        maxBodyLength: 50 * 1024 * 1024
      });

      console.log(`Successfully fetched image: ${url} (${response.data.length} bytes)`);
      return Buffer.from(response.data, 'binary').toString('base64');

    } catch (error) {
      console.error(`Attempt ${attempt}/${maxRetries} failed for ${url}: ${error.message}`);

      if (attempt < maxRetries) {
        const delay = Math.pow(2, attempt) * 1000; 
        console.log(`Waiting ${delay}ms before retry...`);
        await sleep(delay);
      } else {
        console.error(`All ${maxRetries} attempts failed for ${url}`);
        return null;
      }
    }
  }
  return null;
};


const sleep = (ms) => {
  return new Promise(resolve => setTimeout(resolve, ms));
};


const generateCaption = async (imagesData, maxRetries = 3) => {
  try {
    console.log(`Starting caption generation for ${imagesData.length} images`);

    const base64Images = [];
    for (let i = 0; i < imagesData.length; i++) {
      console.log(`Processing image ${i + 1}/${imagesData.length}: ${imagesData[i].url}`);
      const base64 = await imageUrlToBase64(imagesData[i].url);
      base64Images.push(base64);

      if (i < imagesData.length - 1) {
        await sleep(500);
      }
    }

    const validImages = [];
    const failedImageIndices = [];

    for (let i = 0; i < base64Images.length; i++) {
      if (base64Images[i] !== null) {
        validImages.push({
          base64: base64Images[i],
          userNames: imagesData[i].userNames,
          originalIndex: i,
          url: imagesData[i].url
        });
      } else {
        failedImageIndices.push(i);
      }
    }

    console.log(`Successfully processed ${validImages.length}/${imagesData.length} images`);
    if (failedImageIndices.length > 0) {
      console.log(`Failed to process images at indices: ${failedImageIndices.join(', ')}`);
      console.log(`Failed URLs: ${failedImageIndices.map(i => imagesData[i].url).join(', ')}`);
    }

    if (validImages.length === 0) {
      console.error("No valid images to process - all image downloads failed");
      return imagesData.map(imgData => {
        if (imgData.userNames.length > 0) {
          return `Great moments with ${imgData.userNames.join(' and ')}`;
        }
        return "Beautiful memories captured";
      });
    }

    const imageContexts = validImages.map((img, index) => {
      const names = img.userNames.length > 0
        ? `Image ${index + 1}: People present - ${img.userNames.join(', ')}`
        : `Image ${index + 1}: No specific people identified`;
      return names;
    }).join('. ');

    const parts = [
      {
        text: `IMPORTANT: You must generate exactly 3 captions, one for each image I'm sending you.
      
      Context: ${imageContexts}
      
      Generate an engaging Instagram-style caption for each of these 3 images. Each caption should be 1-2 short emotional sentences that can include the names of people mentioned when relevant. Avoid special symbols, double-quotes, single-quotes, excessive punctuation, hashtags, dots, commas, semicolon or headings.
      You Must use every name that provided you
      You MUST return exactly 3 captions in a raw JSON array format, with no surrounding text or markdown fences. 
      Example of the exact format I expect:
      ["Caption for image 1","Caption for image 2","Caption for image 3"] as well not any json raw response.
      
      Return only the JSON array of captions—nothing else.`
      }
    ];

    validImages.forEach(img => {
      parts.push({
        inlineData: {
          mimeType: "image/jpeg",
          data: img.base64
        }
      });
    });

    const payload = {
      contents: [{ parts }]
    };

    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        console.log(`Calling Gemini API (attempt ${attempt}/${maxRetries}) with ${validImages.length} images`);

        const response = await axios.post(API_URL, payload, {
          headers: { 'Content-Type': 'application/json' },
          timeout: 60000
        });

        const rawResponse = response.data.candidates[0]?.content?.parts[0]?.text || "[]";
        console.log('Raw Gemini response:', rawResponse);

        try {
          const captionsArray = JSON.parse(rawResponse);

          if (Array.isArray(captionsArray)) {
            if (captionsArray.length === validImages.length) {
              console.log(`Successfully generated ${captionsArray.length} captions for ${validImages.length} images`);

              if (failedImageIndices.length > 0) {
                const finalCaptions = [];
                let validImageIndex = 0;

                for (let i = 0; i < imagesData.length; i++) {
                  if (failedImageIndices.includes(i)) {
                    const userNames = imagesData[i].userNames;
                    const fallbackCaption = userNames.length > 0
                      ? `Great moments with ${userNames.join(' and ')}`
                      : "Beautiful memories captured";
                    finalCaptions.push(fallbackCaption);
                  } else {
                    finalCaptions.push(captionsArray[validImageIndex]);
                    validImageIndex++;
                  }
                }

                return finalCaptions;
              }

              return captionsArray;
            } else if (captionsArray.length > 0) {
              console.warn(`Mismatch: Got ${captionsArray.length} captions for ${validImages.length} images`);

              if (captionsArray.length > validImages.length) {
                return captionsArray.slice(0, validImages.length);
              }

              while (captionsArray.length < validImages.length) {
                const missingIndex = captionsArray.length;
                const userNames = validImages[missingIndex]?.userNames || [];
                const genericCaption = userNames.length > 0
                  ? `Great moments with ${userNames.join(' and ')}`
                  : "Another beautiful moment captured";
                captionsArray.push(genericCaption);
              }

              return captionsArray;
            }
          }

          return Array(validImages.length).fill(rawResponse);

        } catch (parseError) {
          console.log('Response is not valid JSON, creating fallback captions');
          return validImages.map(img => {
            if (img.userNames.length > 0) {
              return `Cherishing moments with ${img.userNames.join(' and ')}`;
            }
            return "Beautiful memories being made";
          });
        }

      } catch (apiError) {
        if (apiError.response?.status === 429) {
          console.log(`Rate limit hit, attempt ${attempt}/${maxRetries}. Waiting before retry...`);
          if (attempt < maxRetries) {
            const delay = Math.pow(2, attempt) * 1000;
            await sleep(delay);
            continue;
          } else {
            console.error('Max retries reached for rate limiting');
            return Array(validImages.length).fill("Rate limited - unable to generate caption");
          }
        } else {
          console.error(`Gemini API error: ${apiError.message}`);
          throw apiError;
        }
      }
    }

  } catch (error) {
    console.error(`Error generating caption: ${error.message}`);
    return imagesData.map(imgData => {
      if (imgData.userNames.length > 0) {
        return `Great moments with ${imgData.userNames.join(' and ')}`;
      }
      return "Beautiful memories captured";
    });
  }
};

module.exports = {
  generateCaption,
  imageUrlToBase64,
  sleep
};
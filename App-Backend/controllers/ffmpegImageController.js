const downloadAndResizeImages = async (imageUrls, tempDir, axios, fs, ffmpeg, path) => {
  console.log('Downloading and processing images...');
  
  await Promise.all(imageUrls.map(async (url, i) => {
    const filename = `img${String(i + 1).padStart(3, '0')}.jpg`;
    const localPath = path.join(tempDir, filename);
    const resizedPath = path.join(tempDir, `resized_${filename}`);
    
    try {
      const response = await axios.get(url, { 
        responseType: 'stream',
        timeout: 30000
      });
      
      await new Promise((resolve, reject) => {
        response.data.pipe(fs.createWriteStream(localPath))
          .on('finish', resolve)
          .on('error', reject);
      });
      
      await new Promise((resolve, reject) => {
        ffmpeg(localPath)
          .outputOptions([
            '-vf', 'scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black',
            '-q:v', '2'
          ])
          .save(resizedPath)
          .on('end', resolve)
          .on('error', reject);
      });
      
      console.log(`Processed image ${i + 1}/${imageUrls.length}`);
    } catch (err) {
      console.error(`Error processing image ${i + 1}:`, err.message);
      throw new Error(`Failed to process image ${i + 1}: ${err.message}`);
    }
  }));
};


module.exports={
  downloadAndResizeImages
}
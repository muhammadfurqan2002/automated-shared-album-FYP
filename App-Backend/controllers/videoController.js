const { findDefaultAudio, saveUserAudio } =require('../models/audioModel.js');
const { transformImageUrls, videoConfig } =require ('../models/videoModel.js');
const { buildFilterComplex, getOutputOptions } =require ('../views/videoRenderer.js');
const { downloadAndResizeImages } =require ('./ffmpegImageController.js');

const processAudio = async (audioBytes, tempDir, audioDir, fs, path) => {
  let audioPath = null;
  
  if (audioBytes) {
    audioPath = path.join(tempDir, 'user_audio.mp3');
    const success = await saveUserAudio(audioBytes, audioPath, fs);
    if (success) {
      console.log('User audio saved');
    } else {
      console.error('Failed to save user audio');
    }
  } else {
    const audioFile = await findDefaultAudio(audioDir, fs);
    if (audioFile) {
      audioPath = path.join(audioDir, audioFile);
      console.log('Using default audio:', audioFile);
    }
  }
  
  return audioPath;
};


const createVideoWithTransitions = async (tempDir, outputVideo, captions, imageDuration, transitionDuration, imageCount, audioPath, ffmpeg, fs, path) => {
  return new Promise((resolve, reject) => {
    const command = ffmpeg();

    for (let i = 0; i < imageCount; i++) {
      const duration = i === imageCount - 1 ? imageDuration : imageDuration + transitionDuration;
      command.input(path.join(tempDir, `resized_img${String(i + 1).padStart(3, '0')}.jpg`))
        .inputOptions(['-loop', '1', '-t', `${duration}`, '-r', '30']);
    }

    if (audioPath && fs.existsSync(audioPath)) {
      command.input(audioPath);
    }

    const filterComplex = buildFilterComplex(captions, imageCount, imageDuration, transitionDuration);
    console.log('Filter Complex:', filterComplex.substring(0, 500) + '...');
    
    command.complexFilter(filterComplex);

    const outputOptions = getOutputOptions(imageCount, audioPath, fs);
    
    command.outputOptions(outputOptions)
      .output(outputVideo)
      .on('start', (commandLine) => {
        console.log('FFmpeg command:', commandLine.substring(0, 200) + '...');
      })
      .on('progress', (progress) => {
        console.log('Processing: ' + progress.percent + '% done');
      })
      .on('end', () => {
        console.log('Video creation completed successfully');
        resolve();
      })
      .on('error', (err) => {
        console.error('FFmpeg error:', err);
        reject(err);
      })
      .run();
  });
};

const createVideo = async (requestData, tempDir, audioDir, dependencies) => {
  const { axios, fs, ffmpeg, path } = dependencies;
  const { 
    images, 
    captions = [], 
    imageDuration = videoConfig.DEFAULT_IMAGE_DURATION, 
    transitionDuration = videoConfig.DEFAULT_TRANSITION_DURATION, 
    audioBytes = null 
  } = requestData;

  const fullImageUrls = transformImageUrls(images);
  
  const audioPath = await processAudio(audioBytes, tempDir, audioDir, fs, path);
  
  await downloadAndResizeImages(fullImageUrls, tempDir, axios, fs, ffmpeg, path);
  
  console.log('Creating video with transitions...');
  const outputVideo = path.join(tempDir, 'output.mp4');
  await createVideoWithTransitions(
    tempDir, 
    outputVideo, 
    captions, 
    imageDuration, 
    transitionDuration, 
    fullImageUrls.length, 
    audioPath,
    ffmpeg,
    fs,
    path
  );
  
  return outputVideo;
};



module.exports = {
  processAudio,
  createVideoWithTransitions,
  createVideo
};
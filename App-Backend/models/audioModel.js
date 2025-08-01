
const { videoConfig } =require( './videoModel.js');

const findDefaultAudio = async (audioDir, fs) => {
  try {
    const audioFiles = await fs.readdir(audioDir);
    return audioFiles.find(file => 
      videoConfig.SUPPORTED_AUDIO_FORMATS.some(ext => 
        file.toLowerCase().endsWith(ext)
      )
    );
  } catch (err) {
    console.error('Error reading audio directory:', err);
    return null;
  }
};

const saveUserAudio = async (audioBytes, audioPath, fs) => {
  try {
    await fs.writeFile(audioPath, Buffer.from(audioBytes, 'base64'));
    return true;
  } catch (err) {
    console.error('Error saving user audio:', err);
    return false;
  }
};


module.exports={
  saveUserAudio,
 findDefaultAudio 
}
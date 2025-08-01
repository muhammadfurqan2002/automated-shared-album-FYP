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

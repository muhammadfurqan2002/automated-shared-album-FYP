const videoConfig = {
  S3_BASE: 'https://sharedalbum.s3.amazonaws.com/',
  DEFAULT_IMAGE_DURATION: 3.5,
  DEFAULT_TRANSITION_DURATION: 0.5,
  MAX_CHARS_PER_LINE: 40,
  VIDEO_WIDTH: 1920,
  VIDEO_HEIGHT: 1080,
  BASE_FONT_SIZE: 48,
  SUPPORTED_AUDIO_FORMATS: ['.mp3', '.wav', '.m4a', '.aac']
};

const validateVideoRequest = (data) => {
  const { images, captions = [] } = data;
  
  if (!images || !Array.isArray(images) || images.length === 0) {
    return { isValid: false, error: 'Images array is required and cannot be empty' };
  }

  if (captions.length !== images.length) {
    return { isValid: false, error: 'Captions array must match images array length' };
  }

  return { isValid: true };
};

const transformImageUrls = (images) => {
  return images.map(img => 
    img.startsWith('http') ? img : videoConfig.S3_BASE + img
  );
};

const calculateFontSize = (text, maxWidth = 1920, maxHeight = 200) => {
  const baseSize = videoConfig.BASE_FONT_SIZE;
  const textLength = text.length;
  
  if (textLength <= 30) return baseSize;
  if (textLength <= 60) return Math.max(36, baseSize - 8);
  if (textLength <= 100) return Math.max(28, baseSize - 16);
  return Math.max(24, baseSize - 20);
};



module.exports = {
  videoConfig,
  validateVideoRequest,
  transformImageUrls,
  calculateFontSize
};
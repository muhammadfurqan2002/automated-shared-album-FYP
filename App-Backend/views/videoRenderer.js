const { createTextFilter } = require('./textRenderer.js');

function buildFilterComplex(captions, imageCount, imageDuration, transitionDuration) {
  const parts = [];

  // 1) for each image, chain scale→pad→fps→drawtext
  for (let i = 0; i < imageCount; i++) {
    const txt = createTextFilter(captions[i] || '');
    parts.push(
      `[${i}:v]` +
      `scale=1920:-1,` +
      `pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,` +
      `setsar=1,` +
      `fps=30` +
      txt +
      `[v${i}]`
    );
  }

  // 2) xfade chain
  if (imageCount > 1) {
    let prev = 'v0';
    for (let i = 1; i < imageCount; i++) {
      const offset   = (imageDuration - transitionDuration) * i;
      const nextLbl  = i === imageCount - 1 ? 'final' : `c${i}`;
      parts.push(
        `[${prev}][v${i}]` +
        `xfade=transition=fade:duration=${transitionDuration}:offset=${offset}` +
        `[${nextLbl}]`
      );
      prev = nextLbl;
    }
  } else {
    parts.push('[v0]copy[final]');
  }

  // join everything with semicolons
  return parts.join(';');
}

function getOutputOptions(imageCount, audioPath, fs) {
  const opts = [
    '-map', '[final]',
    '-c:v', 'libx264',
    '-preset', 'medium',
    '-crf', '23',
    '-pix_fmt', 'yuv420p',
    '-movflags', '+faststart',
    '-shortest'
  ];

  if (audioPath && fs.existsSync(audioPath)) {
    opts.push('-map', `${imageCount}:a`, '-c:a', 'aac', '-b:a', '128k', '-ac', '2');
  } else {
    opts.push('-an');
  }

  return opts;
}

module.exports = { buildFilterComplex, getOutputOptions };

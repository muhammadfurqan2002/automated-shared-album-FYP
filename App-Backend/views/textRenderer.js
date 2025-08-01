const { escapeFFmpegText, splitTextIntoLines } = require('../models/textModel.js');
const { calculateFontSize }              = require('../models/videoModel.js');

const FONT_PATH = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';

function createTextFilter(caption) {
  if (!caption || !caption.trim()) return '';

  const cleanCaption = escapeFFmpegText(caption.trim());
  const lines        = splitTextIntoLines(cleanCaption, 50);
  const fontSize     = calculateFontSize(cleanCaption);
  const lineHeight   = fontSize + 8;
  const totalH       = lines.length * lineHeight;
  const startY       = `h-${totalH + 60}`;

  // build an array of drawtext filters, *no* leading commas
  const filters = lines.map((line, idx) => {
    const yPos = idx === 0
      ? startY
      : `${startY}+${lineHeight * idx}`;

    return [
      `drawtext=fontfile='${FONT_PATH}'`,
      `text='${line}'`,
      `fontsize=${fontSize}`,
      `fontcolor=white`,
      `shadowcolor=black`,
      `shadowx=2`,
      `shadowy=2`,
      `box=1`,
      `boxcolor=black@0.7`,
      `boxborderw=8`,
      `x=(w-text_w)/2`,
      `y=${yPos}`
    ].join(':');
  });

  // join them with commas so the caller can splice them in
  return filters.length
    ? ',' + filters.join(',')
    : '';
}

module.exports = { createTextFilter };

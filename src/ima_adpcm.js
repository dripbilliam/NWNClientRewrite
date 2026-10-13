// Microsoft/IMA WAVE format 0x11: little-endian predictors, low nibble first,
// four-byte channel groups, initial predictor included in each block's output.
const steps = [7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66, 73, 80, 88, 97, 107, 118, 130, 143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658, 724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066, 2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899, 15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767];
const changes = [-1, -1, -1, -1, 2, 4, 6, 8];
const tag = (b, p) => String.fromCharCode(...b.subarray(p, p + 4));

export function decodeImaWav(input) {
  const b = input instanceof ArrayBuffer ? new Uint8Array(input) : new Uint8Array(input.buffer, input.byteOffset, input.byteLength);
  if (b.length < 12 || tag(b, 0) !== 'RIFF' || tag(b, 8) !== 'WAVE') return null;
  const v = new DataView(b.buffer, b.byteOffset, b.byteLength), end = v.getUint32(4, true) + 8;
  if (end > b.length || end < 12) throw new Error('Truncated WAVE container');
  let fmt, data, fact;
  for (let p = 12; p < end;) {
    if (p + 8 > end) throw new Error('Truncated WAVE chunk header');
    const size = v.getUint32(p + 4, true), start = p + 8, name = tag(b, p);
    if (start + size > end) throw new Error('Truncated WAVE chunk');
    if (name === 'fmt ') { if (fmt) throw new Error('Duplicate WAVE format'); fmt = { start, size }; }
    if (name === 'data') { if (data) throw new Error('Duplicate WAVE data'); data = { start, size }; }
    if (name === 'fact') { if (size < 4) throw new Error('Truncated WAVE fact'); fact = v.getUint32(start, true); }
    p = start + size + (size & 1);
  }
  if (!fmt || fmt.size < 16 || !data) throw new Error('Missing WAVE format/data');
  if (v.getUint16(fmt.start, true) !== 17) return null;
  const channels = v.getUint16(fmt.start + 2, true), sampleRate = v.getUint32(fmt.start + 4, true), blockAlign = v.getUint16(fmt.start + 12, true);
  if (fmt.size < 20 || v.getUint16(fmt.start + 16, true) < 2 || v.getUint16(fmt.start + 14, true) !== 4 || ![1, 2].includes(channels) || !sampleRate || sampleRate > 384000 || blockAlign < channels * 4) throw new Error('Unsupported IMA WAVE format');
  const samplesPerBlock = v.getUint16(fmt.start + 18, true), expected = 1 + (blockAlign - channels * 4) * 2 / channels;
  if (samplesPerBlock !== expected || (channels === 2 && (blockAlign - 8) % 8)) throw new Error('Invalid IMA block size');
  let available = 0;
  for (let p = 0; p < data.size; p += blockAlign) {
    const size = Math.min(blockAlign, data.size - p);
    if (size < channels * 4 || (channels === 2 && (size - 8) % 8)) throw new Error('Truncated IMA block');
    available += 1 + (size - channels * 4) * 2 / channels;
  }
  const frames = fact ?? available;
  if (!frames || frames > available || frames > 16_000_000) throw new Error('Invalid IMA sample count');
  const samples = Array.from({ length: channels }, () => new Float32Array(frames));
  let output = 0;
  for (let start = data.start; start < data.start + data.size; start += blockAlign) {
    const limit = Math.min(start + blockAlign, data.start + data.size), predictor = [], index = [], offsets = [];
    for (let c = 0; c < channels; c++) {
      predictor[c] = v.getInt16(start + c * 4, true); index[c] = b[start + c * 4 + 2]; offsets[c] = output + 1;
      if (index[c] > 88 || b[start + c * 4 + 3] !== 0) throw new Error('Invalid IMA block header');
      if (output < frames) samples[c][output] = predictor[c] / 32768;
    }
    for (let p = start + channels * 4; p < limit;) {
      for (let c = 0; c < channels; c++) {
        const groupEnd = Math.min(p + 4, limit);
        while (p < groupEnd) {
          const byte = b[p++];
          for (const nibble of [byte & 15, byte >> 4]) {
            const step = steps[index[c]];
            let delta = step >> 3;
            if (nibble & 4) delta += step;
            if (nibble & 2) delta += step >> 1;
            if (nibble & 1) delta += step >> 2;
            predictor[c] = Math.max(-32768, Math.min(32767, predictor[c] + (nibble & 8 ? -delta : delta)));
            index[c] = Math.max(0, Math.min(88, index[c] + changes[nibble & 7]));
            if (offsets[c] < frames) samples[c][offsets[c]] = predictor[c] / 32768;
            offsets[c]++;
          }
        }
      }
    }
    output = offsets[0];
  }
  return { sampleRate, samples, frames, channels };
}

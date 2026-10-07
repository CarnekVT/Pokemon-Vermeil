export function audioBufferToWavBytes(buffer) {
  const channels = buffer.numberOfChannels;
  const sampleRate = buffer.sampleRate;
  const length = buffer.length;
  const bytesPerSample = 2;
  const blockAlign = channels * bytesPerSample;
  const dataSize = length * blockAlign;
  const out = new ArrayBuffer(44 + dataSize);
  const view = new DataView(out);
  let p = 0;
  const str = (s) => { for (let i = 0; i < s.length; i++) view.setUint8(p++, s.charCodeAt(i)); };
  str("RIFF"); view.setUint32(p, 36 + dataSize, true); p += 4;
  str("WAVE"); str("fmt "); view.setUint32(p, 16, true); p += 4;
  view.setUint16(p, 1, true); p += 2;
  view.setUint16(p, channels, true); p += 2;
  view.setUint32(p, sampleRate, true); p += 4;
  view.setUint32(p, sampleRate * blockAlign, true); p += 4;
  view.setUint16(p, blockAlign, true); p += 2;
  view.setUint16(p, 16, true); p += 2;
  str("data"); view.setUint32(p, dataSize, true); p += 4;
  const arrays = Array.from({ length: channels }, (_, c) => buffer.getChannelData(c));
  for (let i = 0; i < length; i++) {
    for (let c = 0; c < channels; c++) {
      const x = Math.max(-1, Math.min(1, arrays[c][i]));
      view.setInt16(p, x < 0 ? x * 32768 : x * 32767, true);
      p += 2;
    }
  }
  return Array.from(new Uint8Array(out));
}

export function monoFloatToAudioBuffer(ctx, samples, sampleRate = 44100) {
  const b = ctx.createBuffer(1, samples.length, sampleRate);
  b.copyToChannel(samples, 0);
  return b;
}

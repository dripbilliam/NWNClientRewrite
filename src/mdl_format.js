const ASCII_PREFIX_LENGTH = 4096;

export function isAsciiMdl(input) {
  const bytes = input instanceof Uint8Array ? input : new Uint8Array(input);
  const prefix = new TextDecoder('ascii').decode(bytes.subarray(0, Math.min(bytes.byteLength, ASCII_PREFIX_LENGTH)));
  return prefix.startsWith('#') && /\bnewmodel\s+\S+/i.test(prefix) && /\bbeginmodelgeom\s+\S+/i.test(prefix);
}

export function decodeModelOrientation(orientation, format = 'quaternion') {
  if (!Array.isArray(orientation) || orientation.length < 4 || !orientation.slice(0, 4).every(Number.isFinite)) {
    return [0, 0, 0, 1];
  }
  if (format === 'axis-angle') {
    const axisLength = Math.hypot(orientation[0], orientation[1], orientation[2]);
    if (axisLength < 1e-8 || Math.abs(orientation[3]) < 1e-8) return [0, 0, 0, 1];
    const halfAngle = orientation[3] * 0.5;
    const scale = Math.sin(halfAngle) / axisLength;
    return [
      orientation[0] * scale,
      orientation[1] * scale,
      orientation[2] * scale,
      Math.cos(halfAngle)
    ];
  }
  const length = Math.hypot(...orientation.slice(0, 4));
  if (length < 1e-8) return [0, 0, 0, 1];
  return orientation.slice(0, 4).map(value => value / length);
}
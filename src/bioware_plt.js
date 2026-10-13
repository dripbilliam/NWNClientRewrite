const PLT_PALETTE_NAMES = Object.freeze([
  'pal_skin01',
  'pal_hair01',
  'pal_armor01',
  'pal_armor02',
  'pal_cloth01',
  'pal_cloth01',
  'pal_leath01',
  'pal_leath01',
  'pal_tattoo01',
  'pal_tattoo01'
]);

export function decodeBioWarePlt(input, paletteImages, colorRows = []) {
  const bytes = input instanceof Uint8Array
    ? new Uint8Array(input.buffer, input.byteOffset, input.byteLength)
    : new Uint8Array(input);
  if (bytes.byteLength < 24) throw new Error('BioWare PLT header is truncated.');
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const signature = String.fromCharCode(...bytes.subarray(0, 4));
  const version = String.fromCharCode(...bytes.subarray(4, 8));
  if (signature !== 'PLT ' || version !== 'V1  ') throw new Error('Unsupported BioWare PLT header.');

  const layerCount = view.getUint32(8, true);
  const width = view.getUint32(16, true);
  const height = view.getUint32(20, true);
  const pixelCount = width * height;
  if (!layerCount || layerCount > PLT_PALETTE_NAMES.length || !width || !height || pixelCount > 16_777_216) {
    throw new Error('BioWare PLT dimensions or layer count are invalid.');
  }
  if (24 + pixelCount * 2 > bytes.byteLength) throw new Error('BioWare PLT pixel data is truncated.');

  const output = new Uint8Array(pixelCount * 4);
  for (let pixel = 0; pixel < pixelCount; pixel += 1) {
    const pixelOffset = 24 + pixel * 2;
    const intensity = bytes[pixelOffset];
    const layer = Math.min(bytes[pixelOffset + 1], PLT_PALETTE_NAMES.length - 1);
    const palette = paletteImages.get(PLT_PALETTE_NAMES[layer]);
    if (!palette || palette.width !== 256 || !palette.height || !palette.data) {
      throw new Error(`BioWare PLT palette ${PLT_PALETTE_NAMES[layer]} is unavailable or invalid.`);
    }
    const colorRow = Math.max(0, Math.min(palette.height - 1, Number(colorRows[layer]) || 0));
    const paletteY = palette.height - 1 - colorRow;
    const paletteOffset = (paletteY * palette.width + intensity) * 4;
    const outputOffset = pixel * 4;
    output[outputOffset] = palette.data[paletteOffset];
    output[outputOffset + 1] = palette.data[paletteOffset + 1];
    output[outputOffset + 2] = palette.data[paletteOffset + 2];
    output[outputOffset + 3] = palette.data[paletteOffset + 3];
  }
  // PLT pixels already run from the bottom row (UV v=0) to the top row.
  // Unlike TGALoader's normalized top-down output, these must not be flipped
  // again when uploaded. Keep palette row selection independent of this order.
  return { width, height, data: output, flipY: false };
}

export { PLT_PALETTE_NAMES };

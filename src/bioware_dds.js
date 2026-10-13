import * as THREE from 'three';

export function parseBioWareDds(input) {
  const bytes = input instanceof Uint8Array
    ? new Uint8Array(input.buffer, input.byteOffset, input.byteLength)
    : new Uint8Array(input);
  if (bytes.byteLength < 20) throw new Error('BioWare DDS header is truncated.');

  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const baseWidth = view.getUint32(0, true);
  const baseHeight = view.getUint32(4, true);
  const bytesPerPixel = view.getUint32(8, true);
  const topMipSize = view.getUint32(12, true);
  const expectedSize = bytesPerPixel === 3
    ? baseWidth * baseHeight / 2
    : baseWidth * baseHeight;
  if (!isPowerOfTwo(baseWidth) || !isPowerOfTwo(baseHeight) || baseWidth >= 0x8000 || baseHeight >= 0x8000) {
    throw new Error(`BioWare DDS has invalid dimensions ${baseWidth}x${baseHeight}.`);
  }
  if (bytesPerPixel !== 3 && bytesPerPixel !== 4) {
    throw new Error(`BioWare DDS has unsupported compression marker ${bytesPerPixel}.`);
  }
  if (topMipSize !== expectedSize || topMipSize > bytes.byteLength - 20) {
    throw new Error('BioWare DDS top mip size is invalid.');
  }

  const format = bytesPerPixel === 3 ? THREE.RGB_S3TC_DXT1_Format : THREE.RGBA_S3TC_DXT5_Format;
  const blockSize = bytesPerPixel === 3 ? 8 : 16;
  const mipmaps = [];
  let width = baseWidth;
  let height = baseHeight;
  let offset = 20;
  while (true) {
    const mipSize = Math.ceil(width / 4) * Math.ceil(height / 4) * blockSize;
    if (offset + mipSize > bytes.byteLength) break;
    mipmaps.push({ data: bytes.subarray(offset, offset + mipSize), width, height });
    offset += mipSize;
    if (width === 1 && height === 1) break;
    width = Math.max(1, width >> 1);
    height = Math.max(1, height >> 1);
  }
  if (mipmaps.length === 0) throw new Error('BioWare DDS has no complete mip levels.');

  const texture = new THREE.CompressedTexture(mipmaps, baseWidth, baseHeight, format);
  texture.minFilter = mipmaps.length > 1 ? THREE.LinearMipmapLinearFilter : THREE.LinearFilter;
  texture.magFilter = THREE.LinearFilter;
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.needsUpdate = true;
  return texture;
}

function isPowerOfTwo(value) {
  return Number.isInteger(value) && value > 0 && (value & (value - 1)) === 0;
}
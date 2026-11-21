// Packed native mesh streams. Layout is negotiated with RenderingServer, never
// inferred from a GPU vendor or glTF's accessor packing. No game assets here.
export const MAX_PARTICLE_VERTICES = 196608;
export function validateParticleLayout(layout) {
 if (!layout || layout.vertexStride !== 12 || layout.attributeStride !== 12 || layout.colorOffset !== 0 || layout.uvOffset !== 4)
  throw Error('Unsupported native particle stream layout');
 return layout;
}

export function packParticleBuffers(output, layout, previousCapacity = 0) {
 validateParticleLayout(layout);
 const count = output?.count ?? 0;
 if (!Number.isInteger(count) || count < 0 || count % 6 || count > MAX_PARTICLE_VERTICES || !Number.isInteger(previousCapacity) || previousCapacity < 0 || previousCapacity > MAX_PARTICLE_VERTICES)
  throw Error('Invalid native particle vertex count');
 if (count && (!(output.buffer instanceof ArrayBuffer) || output.buffer.byteLength !== count * 24)) throw Error('Invalid source particle stream');
 const capacity = count > previousCapacity ? Math.min(MAX_PARTICLE_VERTICES, Math.max(96, previousCapacity * 2, count)) : previousCapacity;
 const positions = new ArrayBuffer(capacity * layout.vertexStride), attributes = new ArrayBuffer(capacity * layout.attributeStride);
 const pv = new DataView(positions), av = new DataView(attributes), source = count ? new DataView(output.buffer) : null;
 const min = [Infinity, Infinity, Infinity], max = [-Infinity, -Infinity, -Infinity];
 for (let i = 0; i < count; i++) {
  const at = i * 24, p = [source.getFloat32(at + 4, true), source.getFloat32(at + 12, true), -source.getFloat32(at + 8, true)];
  const uv = [source.getFloat32(at + 16, true), source.getFloat32(at + 20, true)];
  if (![...p, ...uv].every(Number.isFinite)) throw Error('Nonfinite source particle vertex');
  for (let axis = 0; axis < 3; axis++) { pv.setFloat32(i * 12 + axis * 4, p[axis], true); min[axis] = Math.min(min[axis], p[axis]); max[axis] = Math.max(max[axis], p[axis]); }
  av.setUint32(i * 12, source.getUint32(at, true), true);
  av.setFloat32(i * 12 + 4, uv[0], true); av.setFloat32(i * 12 + 8, uv[1], true);
 }
 // Unused capacity is zeroed: degenerate triangles with zero alpha. Updating
 // the full capacity prevents stale quads when the native active list shrinks.
 return {count, capacity, positions, attributes, bounds:count ? {min, max} : null,
  blend:output?.blendMode ?? 0, twoSided:!!output?.twoSided, softInverse:output?.softInverse ?? 0};
}

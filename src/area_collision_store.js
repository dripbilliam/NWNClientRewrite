import { OBJECT_INVALID } from './game_object_array.js';

const f = Math.fround;
const emptyBounds = () => [[1000000, 1000000, 1000000], [-1000000, -1000000, -1000000]];
const objectId = id => {
  if (!Number.isInteger(id) || id < 0 || id > 0xffffffff) throw new Error('Native collision object ID is invalid');
  return id;
};
function vector(value) {
  if (!Array.isArray(value) || value.length !== 3 || !value.every(v => Number.isFinite(v) && Number.isFinite(f(v))))
    throw new Error('Native collision vector is unavailable or invalid');
  return value.map(f);
}
function geometry(vertices, faces) {
  if (!Array.isArray(vertices) || !Array.isArray(faces) || faces.some(face => !Array.isArray(face) || face.length !== 3 ||
    face.some(index => !Number.isInteger(index) || index < 0 || index >= vertices.length)))
    throw new Error('Native collision geometry is unavailable or invalid');
  return vertices.map(vector);
}
function resize(array, size) {
  // Host allocation limit, not a native geometry fallback. Reject before mutation.
  if (!Number.isSafeInteger(size) || size < 0 || size > 16777216) throw new Error('Native collision storage allocation is unsupported');
  if (array.length === size) return array;
  const next = new array.constructor(size); next.set(array.subarray(0, Math.min(size, array.length))); return next;
}
function transform(vertices, orientation, position, replacing = false) {
  const bounds = emptyBounds();
  const result = vertices.map(([x, y, z]) => {
    // Add and Replace use opposite ADDSS operand orders for X. Preserve both.
    const first = f(orientation[0] * y), second = f(x * orientation[1]);
    const point = [f(f(replacing ? second + first : first + second) + position[0]),
      f(f(f(y * orientation[1]) - f(orientation[0] * x)) + position[1]), f(z + position[2])];
    for (let axis = 0; axis < 3; axis++) {
      if (bounds[0][axis] > point[axis]) bounds[0][axis] = point[axis];
      if (point[axis] > bounds[1][axis]) bounds[1][axis] = point[axis];
    }
    return point;
  });
  return { vertices: result, bounds };
}

// CNWArea InitializeStaticObjects140297820, Add140296e60, Grow140297410,
// Remove140298b70, Replace140298d50. Physical parallel arrays, global indices,
// capacity rules and highest-hole reuse follow the native storage, rather than
// a renderer mesh or a Map of independently allocated object triangles.
export class NativeAreaCollisionStore {
  constructor() {
    this.objectCapacity = this.objectCount = this.vertexCapacity = this.vertexCount = 0;
    this.indexCapacity = this.faceCount = this.doorCapacity = this.doorCount = 0;
    this.objectIds = new Uint32Array(); this.faceStarts = new Int32Array(); this.faceCounts = new Int32Array();
    this.vertexStarts = new Int32Array(); this.vertexCounts = new Int32Array();
    this.indices = new Int32Array(); this.vertices = new Float32Array(); this.bounds = new Float32Array();
    this.doorIds = new Uint32Array(); this.doorBounds = new Float32Array();
  }
  add(id, orientation, position, vertices, faces) {
    id = objectId(id); orientation = vector(orientation); position = vector(position); vertices = geometry(vertices, faces);
    const transformed = transform(vertices, orientation, position);
    const vertexBase = this.objectCount === 0 ? 0 : this.vertexCount;
    const faceBase = this.objectCount === 0 ? 0 : this.faceCount;
    let slot = this.objectCount - 1;
    while (slot >= 0 && this.objectIds[slot] !== OBJECT_INVALID) slot--;
    const count = slot < 0 ? this.objectCount + 1 : this.objectCount;
    if (slot < 0) slot = this.objectCount;
    const capacity = this.objectCapacity === 0 ? 16 : count === this.objectCapacity ? this.objectCapacity * 2 : this.objectCapacity;
    let vertexCapacity = this.vertexCapacity;
    if (vertexBase + vertices.length >= vertexCapacity) {
      vertexCapacity ||= 16;
      // Native compares against old CAPACITY + incoming vertices, not live count.
      while (vertexCapacity <= this.vertexCapacity + vertices.length) vertexCapacity *= 2;
    }
    let indexCapacity = this.indexCapacity;
    if (3 * (faceBase + faces.length) >= indexCapacity) {
      indexCapacity ||= 48;
      while (indexCapacity <= 3 * (this.faceCount + faces.length)) indexCapacity *= 2;
    }
    // Allocate all growing arrays before committing live counts or slots.
    const ids = resize(this.objectIds, capacity), starts = resize(this.faceStarts, capacity), counts = resize(this.faceCounts, capacity);
    const vStarts = resize(this.vertexStarts, capacity), vCounts = resize(this.vertexCounts, capacity), bounds = resize(this.bounds, capacity * 6);
    const points = resize(this.vertices, vertexCapacity * 3), indices = resize(this.indices, indexCapacity);
    ids[slot] = id; starts[slot] = faceBase; counts[slot] = faces.length; vStarts[slot] = vertexBase; vCounts[slot] = vertices.length;
    bounds.set(transformed.bounds.flat(), slot * 6);
    for (let i = 0; i < vertices.length; i++) points.set(transformed.vertices[i], 3 * (vertexBase + i));
    for (let i = 0; i < faces.length; i++) indices.set(faces[i].map(index => index + vertexBase), 3 * (faceBase + i));
    Object.assign(this, { objectIds: ids, faceStarts: starts, faceCounts: counts, vertexStarts: vStarts, vertexCounts: vCounts,
      bounds, vertices: points, indices, objectCapacity: capacity, objectCount: count, vertexCapacity, indexCapacity,
      vertexCount: this.vertexCount + vertices.length, faceCount: this.faceCount + faces.length });
    return slot;
  }
  remove(slot) {
    if (slot === -1 || slot >= this.objectCount) return;
    this.checkSlot(slot);
    const vertexBase = this.vertexStarts[slot], vertexCount = this.vertexCounts[slot];
    const faceBase = this.faceStarts[slot], faceCount = this.faceCounts[slot];
    this.vertexStarts[slot] = this.vertexCounts[slot] = this.faceStarts[slot] = this.faceCounts[slot] = 0;
    this.objectIds[slot] = OBJECT_INVALID; this.bounds.set(emptyBounds().flat(), slot * 6);
    this.vertices.copyWithin(vertexBase * 3, (vertexBase + vertexCount) * 3, this.vertexCount * 3);
    for (let index = 3 * (faceBase + faceCount); index < 3 * this.faceCount; index++)
      this.indices[index - 3 * faceCount] = this.indices[index] - vertexCount;
    this.vertexCount -= vertexCount; this.faceCount -= faceCount;
    for (let i = 0; i < this.objectCount; i++) {
      if (this.vertexStarts[i] > vertexBase) this.vertexStarts[i] -= vertexCount;
      if (this.faceStarts[i] > faceBase) this.faceStarts[i] -= faceCount;
    }
  }
  replace(slot, id, orientation, position, vertices, faces) {
    if (slot === -1 || slot >= this.objectCount) return;
    this.checkSlot(slot); id = objectId(id);
    if (this.objectIds[slot] !== id || vertices?.length !== this.vertexCounts[slot] || faces?.length !== this.faceCounts[slot]) return;
    orientation = vector(orientation); position = vector(position); vertices = geometry(vertices, faces);
    const transformed = transform(vertices, orientation, position, true), vertexBase = this.vertexStarts[slot], faceBase = this.faceStarts[slot];
    for (let i = 0; i < vertices.length; i++) this.vertices.set(transformed.vertices[i], 3 * (vertexBase + i));
    for (let i = 0; i < faces.length; i++) this.indices.set(faces[i].map(index => index + vertexBase), 3 * (faceBase + i));
    this.bounds.set(transformed.bounds.flat(), slot * 6);
  }
  getBounds(slot) {
    this.checkSlot(slot); return [Array.from(this.bounds.subarray(slot * 6, slot * 6 + 3)), Array.from(this.bounds.subarray(slot * 6 + 3, slot * 6 + 6))];
  }
  checkSlot(slot) {
    if (!Number.isInteger(slot) || slot < 0 || slot >= this.objectCount) throw new Error('Native collision slot would access invalid memory');
  }
  // AddStaticBoundingBox140296cc0 / RemoveStaticBoundingBox140298ac0:
  // append ordered canonical IDs, permit duplicates, remove only the first.
  addDoorBounds(id, min, max) {
    id = objectId(id); min = vector(min); max = vector(max);
    const capacity = this.doorCount === this.doorCapacity ? Math.max(8, this.doorCapacity * 2) : this.doorCapacity;
    const ids = resize(this.doorIds, capacity), bounds = resize(this.doorBounds, capacity * 6);
    ids[this.doorCount] = id; bounds.set([...min, ...max], this.doorCount * 6);
    this.doorIds = ids; this.doorBounds = bounds; this.doorCapacity = capacity; this.doorCount++; return 0;
  }
  removeDoorBounds(id) {
    id = objectId(id);
    let index = 0; while (index < this.doorCount && this.doorIds[index] !== id) index++;
    if (index === this.doorCount) return 0;
    this.doorCount--;
    this.doorIds.copyWithin(index, index + 1, this.doorCount + 1);
    this.doorBounds.copyWithin(index * 6, (index + 1) * 6, (this.doorCount + 1) * 6); return 1;
  }
}

import { intEntry } from './combat_stats.js';
import { rotateTilePoint } from './tile_surface_mesh.js';
import { clipTileLine } from './tile_line.js';

const f = Math.fround;
const dot = (a, b) => f(f(f(a[0] * b[0]) + f(a[1] * b[1])) + f(a[2] * b[2]));
const vector = values => {
  // Original quarter-turn clipping can produce an IEEE NaN/Infinity Z.
  // Keep those computed FLOATs for the verified LOS kernels. XY remain
  // finite; absent/non-numeric height data is still an unsupported boundary.
  if (!Array.isArray(values) || values.length < 3 || values.slice(0, 2).some(v => !Number.isFinite(v)) || typeof values[2]!=='number')
    throw new Error('Native LOS vector is unavailable');
  return values.slice(0, 3).map(f);
};

// GetLOSMaterials1402beac0 reads exactly64 physical rows. Only integer1
// sets a bit; CheckAABBNode uses SHL EBX,CL (32-bit wrap) then zero extends.
export function tileLOSMaterials(table) {
  if (!table) throw new Error('Native LOS surface table is unavailable');
  let mask = 0n;
  for (let row = 0; row < 64; row++) if (intEntry(table, row, 'LineOfSight').value === 1) mask |= 1n << BigInt(row);
  return mask;
}

// BoxIntersect14022b400..14022b7dd: outcodes, inclusive box faces,
// -1 when the first endpoint is inside, otherwise first X/Y/Z entry face.
export function intersectLOSBox(from, to, minimum, maximum) {
  const a = vector(from), b = vector(to), min = vector(minimum), max = vector(maximum);
  const lowBits = [32, 8, 2], highBits = [16, 4, 1];
  const code = point => point.reduce((bits, value, axis) => bits | (value < min[axis] ? lowBits[axis] : value > max[axis] ? highBits[axis] : 0), 0);
  const first = code(a);
  if (first === 0) return -1;
  if (first & code(b)) return 0;
  for (let axis = 0; axis < 3; axis++) {
    const low = Boolean(first & lowBits[axis]), high = Boolean(first & highBits[axis]);
    if (!low && !high) continue;
    const ratio = f(f((low ? min[axis] : max[axis]) - a[axis]) / f(b[axis] - a[axis]));
    const complement = f(1 - ratio);
    const others = [0, 1, 2].filter(index => index !== axis);
    if (others.every(index => {
      const value = f(f(complement * a[index]) + f(b[index] * ratio));
      return value >= min[index] && value <= max[index];
    })) return axis * 2 + (low ? 1 : 2);
  }
  return 0;
}

// PolyHit1402c41f0..1402c4477. One sided; equal plane distances and
// coplanar rays fail. Inclusive CCW edge tests and native f32 interpolation.
export function hitLOSPolygon(vertices, normal, constant, from, to) {
  const a = vector(from), b = vector(to), n = vector(normal);
  if (!Number.isFinite(constant) || !Array.isArray(vertices) || vertices.length !== 3)
    throw new Error('Native LOS polygon is unavailable');
  const polygon = vertices.map(vector);
  const first = f(dot(n, a) + f(constant));
  // End-plane addition starts with ny*y + nx*x in the original assembly.
  const second = f(f(f(f(n[1] * b[1]) + f(n[0] * b[0])) + f(n[2] * b[2])) + f(constant));
  if (first < 0 || second > 0 || first === second) return null;
  const ratio = f(first / f(first - second)), complement = f(1 - ratio);
  const hit = a.map((value, axis) => f(f(complement * value) + f(ratio * b[axis])));
  for (let index = 0; index < 3; index++) {
    const edge = polygon[(index + 1) % 3].map((value, axis) => f(value - polygon[index][axis]));
    const relative = hit.map((value, axis) => f(value - polygon[index][axis]));
    const cross = [f(f(edge[1] * relative[2]) - f(relative[1] * edge[2])),
      f(f(relative[0] * edge[2]) - f(edge[0] * relative[2])),
      f(f(edge[0] * relative[1]) - f(relative[0] * edge[1]))];
    if (!(dot(cross, n) >= 0)) return null;
  }
  return hit;
}

// CheckAABBNode1402bac30: visit right(+30) before left(+28), without
// short circuiting. Every accepted face mutates the ray endpoint. Direction
// mask is passed recursively but unused in this ordinary two-sided routine.
export function clearTileSurfaceLOS(mesh, direction, from, to, output, materials) {
  const start = vector(from), end = vector(to);
  if (typeof materials !== 'bigint' || materials < 0n || materials > 0xffffffffffffffffn)
    throw new Error('Native LOS material mask is unavailable');
  if (!mesh) throw new Error('Native LOS tile mesh is unavailable');
  if (!mesh.aabb) return 0; // Native ClearLineOfSight silently returns0.
  let hits = 0, visited = 0;
  const stack = [mesh.aabb];
  while (stack.length) {
    if (++visited > 2_000_000) throw new Error('Native LOS AABB traversal is unsupported');
    const node = stack.pop();
    if (intersectLOSBox(start, end, node.min, node.max) === 0) continue;
    if (node.sourceFace === -1) {
      if (!node.left || !node.right) throw new Error('Native LOS AABB children are unavailable');
      stack.push(node.left, node.right);
      continue;
    }
    const partition = node.denied ? mesh.denied : mesh, index = node.face;
    const indices = partition?.faces?.[index], material = partition?.materials?.[index];
    if (!indices || !Number.isInteger(material) || !partition.normals?.[index] || !Number.isFinite(partition.constants?.[index]))
      throw new Error('Native LOS AABB triangle is unavailable');
    if (!(BigInt((1 << (material & 31)) >>> 0) & materials)) continue;
    const vertices = indices.map(i => partition.vertices[i]), normal = partition.normals[index], constant = partition.constants[index];
    const hit = hitLOSPolygon(vertices, normal, constant, start, end) ?? hitLOSPolygon(vertices, normal, constant, end, start);
    if (hit) { end.splice(0, 3, ...hit); hits++; }
  }
  if (hits > 0) output.splice(0, 3, ...end);
  return hits < 1 ? 1 : 0;
}

// CNWSTile ComputeClippedLineSegment1404fd620: select interpolation axis
// using world deltas, divide canonical deltas, preserving quarter-turn quirks.
export function clipAreaTileLOS(tile, from, to) {
  if (!tile.mesh) return { status: 0 };
  const a = vector(from), b = vector(to), ca = rotateTilePoint(tile, a, true), cb = rotateTilePoint(tile, b, true);
  const clipped = clipTileLine(tile.x, tile.y, ca, cb);
  if (clipped.status === 0) return { status: 0 }; // Native outputs are unused by area on failure.
  const epsilon = f(.001);
  const ratio = (point, target, initial) => {
    if (point.every((value, axis) => value >= f(target[axis] - epsilon) && value <= f(target[axis] + epsilon))) return initial;
    if (Math.abs(f(b[0] - a[0])) < epsilon) {
      if (Math.abs(f(b[1] - a[1])) < epsilon) return initial;
      return f(f(point[1] - ca[1]) / f(cb[1] - ca[1]));
    }
    return f(f(point[0] - ca[0]) / f(cb[0] - ca[0]));
  };
  const height = r => f(f(f(b[2] - a[2]) * r) + a[2]);
  const entryHeight = height(ratio(clipped.entry, ca, 0)), exitHeight = height(ratio(clipped.exit, cb, 1));
  return { status: clipped.status, entry: [...rotateTilePoint(tile, clipped.entry, false), entryHeight],
    exit: [...rotateTilePoint(tile, clipped.exit, false), exitHeight] };
}

// CNWSTile ClearLineOfSight1404fd280: tile inverse XY rotation and height
// subtraction, zero-initialized local hit, then convert hit back even on clear.
export function clearAreaTileLOS(tile, direction, from, to, output, materials) {
  if (!tile.mesh) return 0;
  if (!Number.isFinite(tile.heightOffset)) throw new Error('Native LOS tile height is unavailable');
  const origin = [f(f(tile.x) * 10), f(f(tile.y) * 10)];
  const local = point => [...rotateTilePoint(tile, vector(point), true).map((value, axis) => f(value - origin[axis])), f(f(point[2]) - f(tile.heightOffset))];
  const hit = [0, 0, 0], status = clearTileSurfaceLOS(tile.mesh, direction, local(from), local(to), hit, materials);
  output.splice(0, 3, ...rotateTilePoint(tile, hit.slice(0, 2).map((value, axis) => f(value + origin[axis])), false), f(hit[2] + f(tile.heightOffset)));
  return status;
}

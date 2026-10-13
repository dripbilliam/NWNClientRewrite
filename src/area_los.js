import { intersectAreaSegments } from './area_collision.js';
import { normalizeTileVector } from './tile_surface_mesh.js';
import { OBJECT_INVALID } from './game_object_array.js';

const f = Math.fround, tolerance = f(.0001), highEdge = f(9.9999);
const required = (p, name) => {
  if (typeof p[name] !== 'function') throw new Error(`Native area LOS provider ${name} is unavailable`);
  return p[name];
};
const cvtt = value => value >= -2147483648 && value < 2147483648 ? Math.trunc(value) | 0 : -2147483648;
function vector(value) {
  if (!Array.isArray(value) || value.length < 3 || value.slice(0, 3).some(n => !Number.isFinite(n))) throw new Error('Native area LOS vector is unavailable');
  return value.slice(0, 3).map(f);
}

// CNWSArea::ClearLineOfSight14035c590..14035cd0e. Complete assembly
// controls cleanup returns (the decompiler mistakes frees for early returns).
export async function clearAreaLOS(area, from, to, output, hit, sourceId, targetId, transparent, p) {
  hit.id = OBJECT_INVALID; output.splice(0, 3, 0, 0, 0);
  from = vector(from); to = vector(to);
  if (![area.width, area.height].every(Number.isInteger) || !Number.isInteger(transparent)
    || ![sourceId, targetId].every(id => Number.isInteger(id) && id >= 0 && id <= 0xffffffff))
    throw new Error('Native area LOS arguments are unavailable');
  let x = cvtt(f(from[0] * f(.1))), y = cvtt(f(from[1] * f(.1)));
  const direction = (to[0] > from[0] ? 1 : 8) | (to[1] > from[1] ? 2 : 16) | (to[2] > from[2] ? 4 : 32);
  const low = Math.min(from[2], to[2]), high = Math.max(from[2], to[2]);
  let tileResult = 1;
  const visited = new Set();
  for (;;) {
    if (x < 0 || y < 0 || x >= area.width || y >= area.height) return 0;
    const key = `${x}:${y}`;
    if (visited.has(key)) throw new Error('Native area LOS traversal made no progress');
    visited.add(key);
    const tile = await required(p, 'tile')(area, x, y);
    if (!tile) return 0;
    const clipped = await required(p, 'clipTile')(tile, from, to);
    if (clipped.status !== 1) { tileResult = 0; break; }
    const collisionTile = await required(p, 'tile')(area, x, y);
    if (!collisionTile) throw new Error('Native LOS tile disappeared after clipping');
    const tileHit = [0, 0, 0];
    if (await required(p, 'clearTile')(collisionTile, direction, clipped.entry, clipped.exit, tileHit) !== 1) {
      output.splice(0, 3, ...vector(tileHit)); tileResult = 0; break;
    }
    const exit = vector(clipped.exit);
    if (exit.slice(0, 2).every((value, axis) => value >= f(to[axis] - tolerance) && value <= f(to[axis] + tolerance))) break;
    if ((direction & 1) && f(exit[0] - f(f(x) * 10)) >= highEdge) x++;
    if ((direction & 8) && f(exit[0] - f(f(x) * 10)) <= tolerance) x--;
    if ((direction & 2) && f(exit[1] - f(f(y) * 10)) >= highEdge) y++;
    if ((direction & 16) && f(exit[1] - f(f(y) * 10)) <= tolerance) y--;
  }
  let excluded = null;
  // Always perform both native object lookups, including INVALID and duplicates.
  for (const id of [sourceId, targetId]) {
    const object = await required(p, 'object')(id);
    if (object && [9, 10].includes(object.objectType)) (excluded ??= []).push(object);
  }
  const end = tileResult === 0 ? output : to;
  if (await required(p, 'detailed')(area, from.slice(0, 2), end.slice(0, 2), low, high, 0, OBJECT_INVALID, hit, 1, excluded, transparent) !== 0)
    return tileResult;
  if (hit.id === OBJECT_INVALID) return 0;
  const door = await required(p, 'door')(hit.id);
  if (!door) return 0;
  const position = vector(door.nativePosition), orientation = vector(door.nativeOrientation);
  const a = [f(position[0] + orientation[1]), f(position[1] - orientation[0])];
  const b = [f(position[0] - orientation[1]), f(position[1] + orientation[0])];
  const intersection = intersectAreaSegments(from.slice(0, 2), to.slice(0, 2), a, b);
  if (!intersection) return 0;
  const offset = normalizeTileVector(from.map((value, axis) => f(value - position[axis]))).map(value => f(value * f(.3)));
  output.splice(0, 3, f(intersection[0] + offset[0]), f(intersection[1] + offset[1]), f(f(position[2] + 1) + offset[2]));
  return 0;
}

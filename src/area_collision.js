import { OBJECT_INVALID } from './game_object_array.js';

const f = Math.fround;
const required = (providers, name) => {
  if (typeof providers[name] !== 'function') throw new Error(`Native area collision provider ${name} is unavailable`);
  return providers[name];
};
const between = (value, a, b) => value >= Math.min(a, b) && value <= Math.max(a, b);

// Area IntersectLineSegments140297860. General branch tests X intervals only;
// float slope difference, reciprocal and multiply retain native SSE rounding.
export function intersectAreaSegments(from, to, edgeFrom, edgeTo) {
  const [x1, y1] = from.map(f), [x2, y2] = to.map(f), [x3, y3] = edgeFrom.map(f), [x4, y4] = edgeTo.map(f);
  let x, y;
  if (x1 === x2) {
    if (x3 === x4) return null;
    x = x1; const slope = f(f(y4 - y3) / f(x4 - x3));
    y = f(f(y3 - f(slope * x3)) + f(slope * x1));
    if (!between(y, y3, y4) || !between(x, x3, x4) || !between(y, y1, y2)) return null;
  } else {
    const slope = f(f(y2 - y1) / f(x2 - x1));
    if (x3 === x4) {
      x = x3; y = f(f(y1 - f(slope * x1)) + f(slope * x3));
      if (!between(y, y1, y2) || !between(x, x1, x2) || !between(y, y3, y4)) return null;
    } else {
      const edgeSlope = f(f(y4 - y3) / f(x4 - x3)), difference = f(slope - edgeSlope);
      if (difference === 0) return null;
      const constant = f(y3 - f(edgeSlope * x3));
      x = f(f(constant - f(y1 - f(slope * x1))) * f(1 / difference));
      y = f(f(x * edgeSlope) + constant);
      if (!between(x, x3, x4) || !between(x, x1, x2)) return null;
    }
  }
  return [x, y];
}

// Native exclude list stores CGameObject pointers, not guessed/local IDs.
// CNWSArea GetIsIDInExcludeList14035e9f0 scans current canonical object IDs.
export function isCollisionObjectExcluded(id, excluded) {
  if (excluded == null) return 0;
  if (!Array.isArray(excluded)) throw new Error('Native collision exclusion list is invalid');
  for (const object of excluded) {
    if (!object || !Number.isInteger(object.id)) throw new Error('Native collision exclusion object is unavailable');
    if (object.id === id) return 1;
  }
  return 0;
}

function inputs(from, to, low, high, radius) {
  if (!Array.isArray(from) || !Array.isArray(to) || from.length < 2 || to.length < 2 ||
    ![...from.slice(0, 2), ...to.slice(0, 2), low, high, radius].every(v => Number.isFinite(v) && Number.isFinite(f(v))))
    throw new Error('Native area collision query geometry is unavailable');
  radius = f(radius); if (radius > f(.1) && radius <= f(.65)) radius = f(.1);
  return { from: from.map(f), to: to.map(f), low: f(low), high: f(high), radius };
}
function overlaps(bounds, minX, maxX, minY, maxY, low, high) {
  return bounds[0] <= maxX && minX <= bounds[3] && bounds[1] <= maxY && minY <= bounds[4] && bounds[2] <= high && low <= bounds[5];
}
function triangleOverlaps(triangle, minX, maxX, minY, maxY, low, high) {
  return triangle.some(v => v[0] <= maxX) && triangle.some(v => minX <= v[0]) &&
    triangle.some(v => v[1] <= maxY) && triangle.some(v => minY <= v[1]) &&
    triangle.some(v => v[2] <= high) && triangle.some(v => low <= v[2]);
}

// NoNonWalkPolysDetailed140297c50. Preserve slot/triangle/query order, radius
// clamp and static-blocking output-ID behavior. Door geometry is a distinct
// native query, never substituted with a renderer/capsule approximation.
export function noNonWalkPolysDetailed(store, from, to, low, high, radius, ignoredId, output, doorFlag, excluded, transparentFlag, providers = {}) {
  ({ from, to, low, high, radius } = inputs(from, to, low, high, radius));
  if (from[0] === to[0] && from[1] === to[1] || low > high) return 1;
  const dx = f(to[0] - from[0]), dy = f(to[1] - from[1]);
  const length = f(Math.sqrt(f(f(dx * dx) + f(dy * dy)))), ux = f(dx / length), uy = f(dy / length);
  if (!Number.isFinite(length) || length === 0) throw new Error('Native area collision direction is unsupported');
  const sx = f(ux * radius), sy = f(uy * radius), reach = f(length + radius);
  const rectangle = [[f(from[0] - sy), f(sx + from[1])], [f(f(to[0] - sy) + sx), f(f(sx + to[1]) + sy)],
    [f(f(sy + to[0]) + sx), f(f(to[1] - sx) + sy)], [f(sy + from[0]), f(from[1] - sx)]];
  const quadrant = to[0] < from[0] ? (to[1] < from[1] ? 3 : 2) : Number(from[1] <= to[1]);
  const maxX = rectangle[(quadrant + 1) & 3][0], maxY = rectangle[quadrant][1];
  const minX = rectangle[(quadrant - 1) & 3][0], minY = rectangle[(quadrant - 2) & 3][1];
  let remaining = excluded?.length ?? 0;
  const isExcluded = providers.isExcluded ?? isCollisionObjectExcluded;
  for (let slot = 0; slot < store.objectCount; slot++) {
    if (store.faceCounts[slot] === 0) continue;
    if (remaining > 0 && isExcluded(store.objectIds[slot], excluded) !== 0) { remaining--; continue; }
    if (!overlaps(store.bounds.subarray(slot * 6, slot * 6 + 6), minX, maxX, minY, maxY, low, high)) continue;
    for (let face = store.faceStarts[slot], end = face + store.faceCounts[slot]; face < end; face++) {
      const triangle = [0, 1, 2].map(index => {
        const vertex = store.indices[face * 3 + index];
        return Array.from(store.vertices.subarray(vertex * 3, vertex * 3 + 3));
      });
      if (!triangleOverlaps(triangle, minX, maxX, minY, maxY, low, high)) continue;
      const offsets = triangle.map(v => [f(v[0] - from[0]), f(v[1] - from[1])]);
      let right = 0, left = 0, middle = 0, back = 0, beyond = 0;
      for (let i = 0; i < 3; i++) {
        const distance = f(f(offsets[i][0] * -uy) + f(offsets[i][1] * ux));
        if (distance > radius) right |= 1 << i;
        else if (distance < -radius) left |= 1 << i;
        else middle |= 1 << i;
      }
      if (right === 7 || left === 7) continue;
      for (let i = 0; i < 3; i++) {
        const forward = f(f(uy * offsets[i][1]) + f(ux * offsets[i][0]));
        if (forward > reach) beyond |= 1 << i;
        else if (forward < 0) back |= 1 << i;
        else if (middle & 1 << i) return 0;
      }
      if (back === 7 || beyond === 7) continue;
      const masks = [right, beyond, left, back];
      for (let vertex = 0; vertex < 3; vertex++) for (let edge = 0; edge < 4; edge++) {
        const next = (vertex + 1) % 3, bits = (1 << vertex) ^ (1 << next);
        if (masks[edge] & bits && intersectAreaSegments(triangle[vertex], triangle[next], rectangle[edge], rectangle[(edge + 1) & 3])) return 0;
      }
      const [a, b, c] = triangle, [x, y] = rectangle[0];
      if (f(f(f(b[0] - a[0]) * f(y - a[1])) + f(f(x - a[0]) * f(a[1] - b[1]))) >= 0 &&
        f(f(f(c[0] - b[0]) * f(y - b[1])) + f(f(x - b[0]) * f(b[1] - c[1]))) >= 0 &&
        f(f(f(a[0] - c[0]) * f(y - c[1])) + f(f(c[1] - a[1]) * f(x - c[0]))) >= 0) return 0;
    }
  }
  return noNonWalkPolysInDoors(store, from, to, low, high, radius, ignoredId, output, doorFlag, excluded, transparentFlag, providers) === 0 ? 0 : 1;
}

// NoNonWalkPolysInDoors140298700: ordered live door bounds, canonical-ID
// dispatch, then virtual HandleTransparentDoors(+10) only for exact flag1.
export function noNonWalkPolysInDoors(store, from, to, low, high, radius, ignoredId, output, doorFlag, excluded, transparentFlag, providers = {}) {
  ({ from, to, low, high, radius } = inputs(from, to, low, high, radius));
  const minX = f(Math.min(from[0], to[0]) - radius), maxX = f(Math.max(from[0], to[0]) + radius);
  const minY = f(Math.min(from[1], to[1]) - radius), maxY = f(Math.max(from[1], to[1]) + radius);
  const isExcluded = providers.isExcluded ?? isCollisionObjectExcluded;
  for (let index = 0; index < store.doorCount; index++) {
    const bounds = store.doorBounds.subarray(index * 6, index * 6 + 6);
    // Native uses OR pairs, including reversed height inputs in this direct query.
    if (!(bounds[0] <= minX || bounds[0] <= maxX) || !(maxX <= bounds[3] || minX <= bounds[3]) ||
      !(bounds[1] <= minY || bounds[1] <= maxY) || !(maxY <= bounds[4] || minY <= bounds[4]) ||
      !(bounds[2] <= low || bounds[2] <= high) || !(high <= bounds[5] || low <= bounds[5])) continue;
    const id = store.doorIds[index];
    if (isExcluded(id, excluded) !== 0 || required(providers, 'doorPolygons')(id, from, to, low, high, radius, ignoredId, doorFlag) !== 0) continue;
    if (!output) throw new Error('Native door collision output is unavailable');
    output.id = id;
    if (transparentFlag !== 1) return 0;
    return required(providers, 'transparentDoor')(store, from, to, low, high, radius, ignoredId, output, doorFlag, excluded ?? [], 1);
  }
  return 1;
}

// CNWSArea::NoNoneWalkPolysInStaticObject14036f420 closed-door gate.
export function queryDoorPolygons(id, from, to, low, high, radius, ignoredId, flag, providers) {
  const door = required(providers, 'object')(id);
  if (!door || door.objectType !== 10) return 0;
  const state = required(providers, 'doorOpenState')(door);
  if (!Number.isInteger(state) || state < 0 || state > 255) throw new Error('Native door open state is unavailable');
  if (state === 0 && ignoredId !== id && flag !== 1) return 1;
  return required(providers, 'doorSurface')(door, from, to, low, high, radius);
}

// CNWSArea HandleTransparentDoors14035ee80. Active generic/base door table
// integer BlockSight lookup; append canonical object, retry Detailed with flag0.
export function handleTransparentDoor(store, from, to, low, high, radius, ignoredId, output, flag, excluded, _transparentFlag, providers) {
  if (output.id === OBJECT_INVALID) return 0;
  const door = required(providers, 'object')(output.id);
  if (!door || door.objectType !== 10) return 0;
  const blocks = required(providers, 'doorBlockSight')(door);
  if (!Number.isInteger(blocks)) throw new Error('Native door BlockSight integer is unavailable');
  if (blocks !== 0 || excluded == null) return 0;
  excluded.push(door);
  return noNonWalkPolysDetailed(store, from, to, low, high, radius, ignoredId, output, flag, excluded, 0, providers);
}

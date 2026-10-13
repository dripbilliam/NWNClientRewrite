import { tileOrientationQuaternion, rotateTileQuaternion, normalizeTileVector, noDeniedTilePolygons } from './tile_surface_mesh.js';
import { intersectAreaSegments } from './area_collision.js';
import { nativeSinf, nativeCosf } from './native_math.js';

const f = Math.fround;
const mesh = () => ({ vertices: [], faces: [], materials: [] });
function values(tokens, count, label, integer = false) {
  const result = tokens.map(Number);
  if (result.length < count || result.slice(0, count).some(v => !Number.isFinite(v) || !Number.isFinite(f(v)) || integer && !Number.isInteger(v)))
    throw new Error(`Invalid native object mesh ${label}`);
  return result.slice(0, count).map(v => integer ? v | 0 : f(v));
}

// CNWPlaceableSurfaceMesh::LoadWalkMesh1402ce0b0 and door1402cf720 ASCII
// paths. Collision arrays retain every face material, duplicates and original
// indices. No tile +5 shift, tile snapping, dedup or surfacemat Walk filtering.
// Node position/quaternion carry between nodes in the native loader.
export function parseObjectSurfaceMesh(input, kind, providers = {}) {
  if (!['placeable', 'door'].includes(kind)) throw new Error('Native object mesh kind is invalid');
  const text = typeof input === 'string' ? input : new TextDecoder('ascii').decode(input);
  if (text.includes('\0')) throw new Error('Native binary object mesh sections are not implemented');
  const lines = text.replaceAll('\r', '').split('\n'), states = kind === 'door' ? [mesh(), mesh(), mesh()] : [mesh()];
  let active = null, offset = [0, 0, 0], quaternion = [1, 0, 0, 0];
  const tags = states.map(() => new Set());
  for (let line = 0; line < lines.length; line++) {
    const trimmed = lines[line].trimStart(), tokens = trimmed.trimEnd().split(/\s+/), command = tokens[0];
    if (trimmed.length > 254) throw new Error('Native object mesh long-line parsing is not implemented');
    if (command === 'node') {
      active = null;
      if (kind === 'placeable' && tokens[1] === 'trimesh') active = 0;
      else if (kind === 'door' && tokens[1] === 'trimesh') {
        // Native fixed byte offset skips exactly two model-name characters.
        const name = String(tokens[2] ?? '').slice(2), state = name.match(/^_DWK_wg_(closed|open1|open2)/);
        if (state) active = { closed: 0, open1: 1, open2: 2 }[state[1]];
      }
      continue;
    }
    if (command === 'endnode') { active = null; continue; }
    if (active === null) continue;
    if (command === 'position') offset = values(tokens.slice(1), 3, 'position');
    else if (command === 'orientation') quaternion = (providers.quaternionForOrientation ?? tileOrientationQuaternion)(values(tokens.slice(1), 4, 'orientation'));
    else if (['verts', 'vertices', 'faces'].includes(command)) {
      const count = Number(tokens[1]), tag = command === 'faces' ? 'faces' : 'vertices';
      if (!Number.isInteger(count) || count < 0 || count > 2_000_000) throw new Error('Invalid native object mesh row count');
      if (tokens.length > 2) throw new Error('Native binary object mesh row sections are not implemented');
      if (tags[active].has(tag)) throw new Error(`Repeated native object mesh ${tag} section is not implemented`);
      tags[active].add(tag);
      for (let row = 0; row < count; row++) {
        if (++line >= lines.length) throw new Error('Truncated native object mesh rows');
        const parts = lines[line].trim().split(/\s+/);
        if (tag === 'vertices') states[active].vertices.push(rotateTileQuaternion(quaternion, values(parts, 3, 'vertex')).map((v, axis) => f(offset[axis] + v)));
        else {
          const face = values(parts, 8, 'face', true);
          states[active].faces.push(face.slice(0, 3)); states[active].materials.push(face[7]);
        }
      }
    }
  }
  // Native permits resources with no collision nodes (decorative placeables).
  // Empty loaded arrays differ from failed/missing resource resolution.
  for (const state of states) if (state.faces.some(face => face.some(index => index < 0 || index >= state.vertices.length)))
    throw new Error('Native object mesh negative or invalid indices are not implemented');
  return kind === 'door' ? { states } : states[0];
}

// GetMeshBoundingBox1402cf0a0: all three state vertex arrays, first vertex
// seeds bounds, mutate caller's orientation to [y,-x,z], without normalization.
export function doorMeshBoundingBox(surface, position, orientation) {
  if (!surface?.states || ![...position, ...orientation].every(Number.isFinite)) throw new Error('Native door mesh bounding geometry is unavailable');
  const ox = f(orientation[0]), oy = f(orientation[1]);
  orientation[0] = oy; orientation[1] = -ox;
  let bounds = null;
  for (const state of surface.states) for (const [x, y, z] of state.vertices) {
    const point = [f(f(f(oy * x) + f(-ox * y)) + f(position[0])),
      f(f(f(oy * y) - f(-ox * x)) + f(position[1])), f(z + f(position[2]))];
    if (!bounds) bounds = [[...point], [...point]];
    else for (let axis = 0; axis < 3; axis++) {
      if (point[axis] > bounds[1][axis]) bounds[1][axis] = point[axis];
      if (bounds[0][axis] > point[axis]) bounds[0][axis] = point[axis];
    }
  }
  return { status: Number(bounds !== null), bounds };
}

// Door IntersectLineSegments1402cf270 adds a normalized dot==1 rejection
// before the slope branches. Heights are not read by the collision caller.
export function intersectDoorSurfaceSegments(from, to, edgeFrom, edgeTo) {
  from = from.map(f); to = to.map(f); edgeFrom = edgeFrom.map(f); edgeTo = edgeTo.map(f);
  const dx = f(to[0] - from[0]), dy = f(to[1] - from[1]), ex = f(edgeTo[0] - edgeFrom[0]), ey = f(edgeTo[1] - edgeFrom[1]);
  const a = f(Math.sqrt(f(f(dx * dx) + f(dy * dy)))), b = f(Math.sqrt(f(f(ex * ex) + f(ey * ey))));
  if (f(f(f(f(dx * ex) + f(ey * dy)) / a) / b) === 1) return null;
  return intersectAreaSegments(from, to, edgeFrom, edgeTo);
}

// Area LoadDoors1403608f0 / LoadPlaceables1403619e0: quaternion-derived
// facing from half bearing, with native f32 subtraction/doubling/normalization.
// Direct sin(bearing)/cos(bearing) does not preserve this arithmetic.
export function nativePlacementOrientation(bearing) {
  if (!Number.isFinite(bearing)) throw new Error('Native placement bearing is unavailable');
  const half = f(f(bearing) * f(.5)), sine = nativeSinf(half), cosine = nativeCosf(half);
  const axisX = f(0 * sine), axisY = f(0 * sine), axisZ = f(1 * sine);
  const side = f(f(axisY * axisX) - f(cosine * axisZ)), x = f(side + side);
  const squared = f(f(axisZ * axisZ) + f(axisX * axisX)), y = f(1 - f(squared + squared));
  const magnitude = f(f(f(y * y) + f(x * x)) + 0);
  return magnitude <= f(1e-8) ? [0, 1, 0] : normalizeTileVector([x, y, 0]);
}

// Door surface1402d0170 has the same uncleared inside scratch flags as tile
// collision. Complete assembly rbp+48/+4c/+50 only clears them to0. Retain
// ambiguity, actual state arrays and door intersection's dot-product gate.
export function noDoorSurfacePolygons(surface, state, from, to, low, high, radius, initialInside) {
  const selected = surface?.states?.[state];
  if (!selected) throw new Error('Native door collision state is unavailable');
  return noDeniedTilePolygons({ denied: selected }, from, to, low, high, radius, 0, initialInside,
    { clampRadius: false, intersect: intersectDoorSurfaceSegments, scratchLabel: 'door' });
}

// CNWSDoor NoNonWalkPolysInDoor1404224c0. Actual animation IDs dispatch to
// mesh-state globals, including destroyed72 and unsupported-state blocking.
export function noDoorPolygons(door, from, to, low, high, radius, stateGlobals, initialInside) {
  const animation = door.nativeAnimation;
  if (![22, 50, 51].includes(animation)) return animation === 72 ? 1 : 0;
  if (!door.nativeDoorSurface) return 0;
  const state = stateGlobals?.[animation];
  if (!Number.isInteger(state) || state < 0 || state > 2) throw new Error('Native door collision-state global is unavailable');
  const orientation = normalizeTileVector(door.nativeOrientation.map(f)), position = door.nativePosition.map(f);
  const transform = point => {
    const x = f(f(point[0]) - position[0]), y = f(f(point[1]) - position[1]);
    return [f(f(-orientation[0] * y) + f(orientation[1] * x)), f(f(orientation[1] * y) - f(-orientation[0] * x))];
  };
  return noDoorSurfacePolygons(door.nativeDoorSurface, state, transform(from), transform(to), f(f(low) - position[2]), f(f(high) - position[2]), radius, initialInside) === 0 ? 0 : 1;
}

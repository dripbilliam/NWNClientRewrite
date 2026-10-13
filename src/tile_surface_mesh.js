import { clipTileLine } from './tile_line.js';
import { intEntry } from './combat_stats.js';
import { nativeCosf, nativeSinf } from './native_math.js';

const f = Math.fround;
const lowEdge = f(0.0001), highEdge = f(9.9999);
export const TILE_BORDER = -2;
export const TILE_NO_NEIGHBOR = -3;

// CNWTileSurfaceMesh::ComputeTriangleAdjacency 1402bc850..1402bcbf1.
// Match vertex indices, including same-direction edges. Border edges take
// precedence over matching faces; for non-manifold edges the last match wins.
export function computeTileAdjacency(vertices, faces) {
  validateGeometry(vertices, faces);
  vertices = vertices.map(vertex => vertex.map(f));
  const boundary = vertices.map(([x, y]) => x <= lowEdge || y <= lowEdge || x >= highEdge || y >= highEdge);
  const adjacency = faces.map(() => [TILE_NO_NEIGHBOR, TILE_NO_NEIGHBOR, TILE_NO_NEIGHBOR]);
  for (let face = 0; face < faces.length; face++) {
    for (let edge = 0; edge < 3; edge++) {
      if (adjacency[face][edge] !== TILE_NO_NEIGHBOR) continue;
      const a = faces[face][edge], b = faces[face][(edge + 1) % 3];
      if (boundary[a] && boundary[b] && [0, 1].some(axis =>
        vertices[a][axis] <= lowEdge && vertices[b][axis] <= lowEdge ||
        vertices[a][axis] >= highEdge && vertices[b][axis] >= highEdge)) {
        adjacency[face][edge] = TILE_BORDER;
        continue;
      }
      for (let candidate = face + 1; candidate < faces.length; candidate++) {
        for (let otherEdge = 0; otherEdge < 3; otherEdge++) {
          const c = faces[candidate][otherEdge], d = faces[candidate][(otherEdge + 1) % 3];
          if (a === c && b === d || a === d && b === c) {
            adjacency[candidate][otherEdge] = face;
            adjacency[face][edge] = candidate;
          }
        }
      }
    }
  }
  return adjacency;
}

// Native ASCII branch of LoadWalkMesh 1402c1020..1402c2f75. Only aabb
// nodes own tile collision geometry. Binary row sections and nonzero node
// rotations require their actual decoders/math provider, never viewer math.
// The resulting arrays retain native Walk integer semantics (nonzero),
// source face order, snapped/deduplicated indices and cached plane values.
export function parseTileSurfaceMesh(input, surfaceTable, providers = {}) {
  if (!surfaceTable) throw new Error('Native surfacemat table is unavailable');
  const text = typeof input === 'string' ? input : new TextDecoder('ascii').decode(input);
  const lines = text.replaceAll('\r', '').split('\n');
  let active = false, found = false, offset = [0, 0, 0], quaternion = [1, 0, 0, 0];
  let vertices = [], faces = [], materials = [], vertexMap = [], aabbRows = [];
  for (let lineIndex = 0; lineIndex < lines.length; lineIndex++) {
    const tokens = lines[lineIndex].trim().split(/\s+/), command = tokens[0];
    if (command === 'node') {
      active = tokens[1] === 'aabb';
      if (active) {
        if (found) throw new Error('Multiple native tile aabb nodes are not implemented');
        found = true;
      }
      continue;
    }
    if (command === 'endnode') { active = false; continue; }
    if (!active) continue;
    if (command === 'position') {
      const values = numbers(tokens.slice(1), 3, 'position');
      offset = [f(values[0] + 5), f(values[1] + 5), values[2]];
    } else if (command === 'orientation') {
      const orientation = numbers(tokens.slice(1), 4, 'orientation');
      if (orientation[3] === 0 || orientation.slice(0, 3).every(value => value === 0)) quaternion = [1, 0, 0, 0];
      else {
        quaternion = numbers((providers.quaternionForOrientation ?? tileOrientationQuaternion)(orientation), 4, 'quaternion');
      }
    } else if (command === 'aabb') {
      if (aabbRows.length) throw new Error('Repeated native tile AABB sections are not implemented');
      // LoadWalkMesh1402c1d46 reads preorder rows until the root is complete.
      // Bounds transform both authored corners, reorder axes, then expand .01.
      let pending = 1;
      let rowTokens = tokens.slice(1);
      while (pending > 0) {
        if (rowTokens.length !== 7) throw new Error('Invalid native tile AABB row');
        const values = rowTokens.map(Number), face = values[6];
        if (!Number.isInteger(face) || face < -1) throw new Error('Invalid native tile AABB face');
        const corners = [0, 3].map(start => rotateTileQuaternion(quaternion, numbers(values.slice(start), 3, 'AABB corner'))
          .map((value, axis) => f(value + offset[axis])));
        aabbRows.push({ min: corners[0].map((value, axis) => f(Math.min(value, corners[1][axis]) - f(.01))),
          max: corners[0].map((value, axis) => f(Math.max(value, corners[1][axis]) + f(.01))), sourceFace: face });
        pending += face === -1 ? 1 : -1;
        if (aabbRows.length > 2_000_000) throw new Error('Native tile AABB allocation is unsupported');
        if (pending > 0) {
          if (++lineIndex >= lines.length) throw new Error('Truncated native tile AABB tree');
          rowTokens = lines[lineIndex].trim().split(/\s+/);
        }
      }
    } else if (command === 'verts' || command === 'vertices' || command === 'faces') {
      if (command === 'faces' ? faces.length : vertexMap.length) throw new Error(`Repeated native tile ${command} sections are not implemented`);
      const count = Number(tokens[1]);
      if (!Number.isInteger(count) || count < 0 || count > 2_000_000) throw new Error(`Invalid native tile ${command} count`);
      if (tokens.length > 2) throw new Error('Native binary tile mesh row sections are not implemented');
      const known = new Map();
      for (let row = 0; row < count; row++) {
        if (++lineIndex >= lines.length) throw new Error(`Truncated native tile ${command} section`);
        const values = lines[lineIndex].trim().split(/\s+/).map(Number);
        if (command !== 'faces') {
          const vertex = rotateTileQuaternion(quaternion, numbers(values, 3, 'vertex'))
            .map((value, axis) => snapTileVertex(f(value + offset[axis])));
          const key = vertex.join(':');
          if (!known.has(key)) { known.set(key, vertices.length); vertices.push(vertex); }
          vertexMap.push(known.get(key));
        } else {
          if (values.length < 8 || values.slice(0, 8).some(value => !Number.isInteger(value))) throw new Error('Invalid native tile face row');
          if (values.slice(0, 3).some(index => index < 0 || index >= vertexMap.length)) throw new Error('Native tile face index outside vertex array');
          faces.push(values.slice(0, 3).map(index => vertexMap[index])); materials.push(values[7] | 0);
        }
      }
    }
  }
  if (!found) throw new Error('Native tile mesh has no aabb collision node');
  validateGeometry(vertices, faces);
  const normals = faces.map(indices => tileTriangleNormal(...indices.map(index => vertices[index])));
  const constants = normals.map((normal, index) => {
    const vertex = vertices[faces[index][0]];
    return f(-f(f(f(vertex[1] * normal[1]) + f(vertex[0] * normal[0])) + f(vertex[2] * normal[2])));
  });
  const partitions = [true, false].map(walkable => {
    const selected = faces.map((_, index) => index).filter(index => (intEntry(surfaceTable, materials[index], 'Walk').value !== 0) === walkable);
    const used = new Set(selected.flatMap(index => faces[index]));
    const indices = vertices.map((_, index) => index).filter(index => used.has(index));
    const remap = new Map(indices.map((index, mapped) => [index, mapped]));
    return { vertices: indices.map(index => vertices[index]), faces: selected.map(index => faces[index].map(vertex => remap.get(vertex))),
      normals: selected.map(index => normals[index]), constants: selected.map(index => constants[index]),
      materials: selected.map(index => materials[index]), sourceFaces: selected };
  });
  const [walkable, denied] = partitions;
  walkable.adjacency = computeTileAdjacency(walkable.vertices, walkable.faces);
  let aabb = null;
  const stack = [];
  for (const row of aabbRows) {
    const node = { ...row, left: null, right: null };
    if (node.sourceFace !== -1) {
      const source = node.sourceFace;
      if (source >= faces.length) throw new Error('Native tile AABB face outside triangle array');
      node.denied = intEntry(surfaceTable, materials[source], 'Walk').value === 0;
      node.face = partitions[node.denied ? 1 : 0].sourceFaces.indexOf(source);
    }
    if (!aabb) aabb = node;
    else {
      const parent = stack.at(-1);
      if (!parent) throw new Error('Invalid native tile AABB tree structure');
      if (!parent.left) parent.left = node;
      else { parent.right = node; stack.pop(); }
    }
    if (node.sourceFace === -1) stack.push(node);
  }
  if (stack.length) throw new Error('Truncated native tile AABB tree');
  return { ...walkable, denied, aabb };
}

// Native cvttss2si(x*512+.5), snap only when the integer remainder is0.
// This includes the asymmetric behavior for negative coordinates.
export function snapTileVertex(value) {
  value = f(value);
  const scaled = f(f(value * 512) + f(.5));
  const integer = scaled >= -2147483648 && scaled < 2147483648 ? Math.trunc(scaled) | 0 : -2147483648;
  return integer % 512 === 0 ? f(integer >> 9) : value;
}

// NormalOf 14022d960 and normalize 140230920: cross(b-a,c-b), with
// native near-unit bypass and sqrtf(1 / squared magnitude).
export function tileTriangleNormal(a, b, c) {
  const u = b.map((value, axis) => f(value - a[axis])), v = c.map((value, axis) => f(value - b[axis]));
  const vector = [f(f(u[1] * v[2]) - f(u[2] * v[1])), f(f(u[2] * v[0]) - f(u[0] * v[2])), f(f(u[0] * v[1]) - f(u[1] * v[0]))];
  return normalizeTileVector(vector);
}
export function normalizeTileVector(vector) {
  const lengthSquared = f(f(f(vector[0] * vector[0]) + f(vector[1] * vector[1])) + f(vector[2] * vector[2]));
  if (lengthSquared >= f(.99999) && lengthSquared <= f(1.00001)) return vector;
  if (lengthSquared === 0) return [1, 0, 0];
  const inverse = f(Math.sqrt(f(1 / lengthSquared)));
  return vector.map(value => f(value * inverse));
}

// LoadWalkMesh orientation branch: normalize the axis (14022db30),
// half-angle in f32, native cosf/sinf, then scale axis components in f32.
export function tileOrientationQuaternion(orientation) {
  const [x, y, z, angle] = orientation.map(f);
  if (x === 0 && y === 0 && z === 0) return [1, 0, 0, 0];
  const axis = normalizeTileVector([x, y, z]), halfAngle = f(angle * f(.5));
  const cosine = nativeCosf(halfAngle), sine = nativeSinf(halfAngle);
  return [cosine, ...axis.map(value => f(value * sine))];
}

// Quaternion*Vector 14022ae90..14022b0ba; output addition order follows
// native SSE. Quaternion components are [w,x,y,z].
export function rotateTileQuaternion(q, vector) {
  const [w, x, y, z] = q.map(f), [vx, vy, vz] = vector.map(f);
  if (w === 1 || vx === 0 && vy === 0 && vz === 0 || x === 0 && y === 0 && z === 0) return [vx, vy, vz];
  const xx = f(x*x), yy = f(y*y), zz = f(z*z), xy = f(x*y), zx = f(z*x), zy = f(z*y), xw = f(x*w), yw = f(y*w), zw = f(z*w);
  const twice = value => f(value + value);
  return [
    f(f(f(f(1-twice(f(zz+yy))) * vx) + f(twice(f(xy-zw)) * vy)) + f(twice(f(yw+zx)) * vz)),
    f(f(f(f(1-twice(f(zz+xx))) * vy) + f(twice(f(xy+zw)) * vx)) + f(twice(f(zy-xw)) * vz)),
    f(f(f(twice(f(zy+xw)) * vy) + f(twice(f(zx-yw)) * vx)) + f(f(1-twice(f(yy+xx))) * vz))
  ];
}
function numbers(values, count, kind) {
  if (values.length < count || values.slice(0, count).some(value => !Number.isFinite(Number(value)))) throw new Error(`Invalid native tile ${kind}`);
  return values.slice(0, count).map(value => f(Number(value)));
}

// PlaneHeightAtPoint 14022de80..14022deb9. Addition order is nx*x+d,
// followed by ny*y; vertical planes return positive zero.
export function tilePlaneHeight(normal, constant, point) {
  const [nx, ny, nz] = normal.map(f);
  return nz === 0 ? 0 : f(-f(f(f(ny * f(point[1])) + f(f(nx * f(point[0])) + f(constant))) / nz));
}

// ComputeHeight1402bc3d0..1402bc7e0: first containing walkable face,
// then first denied face, source order. Input Z never selects an upper floor.
export function tileSurfaceHeight(mesh, point) {
  const [x,y] = point.map(f);
  if (![x,y].every(Number.isFinite)) throw new Error('Native tile height point is unavailable');
  for (const partition of [mesh,mesh.denied]) {
    if (!partition?.faces || !partition.vertices || !partition.normals || !partition.constants) throw new Error('Native tile height geometry is unavailable');
    for (let index=0;index<partition.faces.length;index++) {
      const [a,b,c]=partition.faces[index].map(i=>partition.vertices[i]);
      const edge=(a,b)=>f(f(f(y-a[1])*f(b[0]-a[0]))+f(f(a[1]-b[1])*f(x-a[0])));
      if (edge(a,b)>=0 && edge(b,c)>=0 && edge(c,a)>=0)
        return tilePlaneHeight(partition.normals[index],partition.constants[index],[x,y,0]);
    }
  }
  return 0;
}

// CNWSTile::ComputeHeight1404fd9a0. Rotate tile-local XY then add the
// loaded tile offset once; this does not use renderer triangle picking.
export function areaTileHeight(tile,point) {
  const real=[f(f(point[0])-f(f(tile.x)*10)),f(f(point[1])-f(f(tile.y)*10))];
  const local=rotateTilePoint({...tile,x:0,y:0},real,true);
  if (!tile.mesh || !Number.isFinite(tile.heightOffset)) throw new Error('Native tile height resource is unavailable');
  return f(tileSurfaceHeight(tile.mesh,local)+f(tile.heightOffset));
}

// IntersectLineSegments 1402bf510..1402bf969. Collinear/parallel lines
// fail; contacts at endpoints count. Height comes from the crossed edge,
// choosing its larger horizontal component, not from the movement line.
export function intersectTileSegments(start, end, edgeStart, edgeEnd) {
  const [x1, y1] = start.map(f), [x2, y2] = end.map(f);
  const [x3, y3, z3] = edgeStart.map(f), [x4, y4, z4] = edgeEnd.map(f);
  let x, y;
  if (x1 !== x2) {
    const slope = f(f(y2 - y1) / f(x2 - x1));
    if (x3 === x4) {
      x = x3;
      y = f(f(y1 - f(x1 * slope)) + f(x3 * slope));
      if (!between(y, y1, y2) || !between(x, x1, x2) || !between(y, y3, y4)) return null;
    } else {
      const edgeSlope = f(f(y4 - y3) / f(x4 - x3));
      if (slope === edgeSlope) return null;
      const edgeConstant = f(y3 - f(x3 * edgeSlope));
      x = f(f(edgeConstant - f(y1 - f(x1 * slope))) * f(1 / f(slope - edgeSlope)));
      y = f(f(x * edgeSlope) + edgeConstant);
      if (!between(x, x3, x4) || !between(x, x1, x2)) return null;
    }
  } else {
    if (x3 === x4) return null;
    x = x1;
    const slope = f(f(y4 - y3) / f(x4 - x3));
    y = f(f(y3 - f(x3 * slope)) + f(x1 * slope));
    if (!between(y, y3, y4) || !between(x, x3, x4) || !between(y, y1, y2)) return null;
  }
  const fraction = Math.abs(f(x3 - x4)) < Math.abs(f(y3 - y4))
    ? f(f(y - y3) / f(y4 - y3)) : f(f(x - x3) / f(x4 - x3));
  return [x, y, f(f(f(z4 - z3) * fraction) + z3)];
}

// ClippedLineSegmentWalkable 1402bb580..1402bbf51. Mesh fields are native
// canonical tile coordinates (0..10); the loader supplies native cached
// planes and the final, classified top-level faces. Do not pass the viewer's
// filtered triangles, which lose indices and native adjacency sentinels.
export function clippedTileSurfaceLine(mesh, tileX, tileY, from, to, onWarning = null) {
  validateGeometry(mesh.vertices, mesh.faces);
  if (mesh.adjacency?.length !== mesh.faces.length || mesh.normals?.length !== mesh.faces.length || mesh.constants?.length !== mesh.faces.length)
    throw new Error('Native tile mesh adjacency or cached planes are unavailable');
  const clipped = clipTileLine(tileX, tileY, from, to);
  const result = { ...clipped, status: 0, minHeight: 0, maxHeight: 0 };
  if (clipped.status === 0) return result;
  const originX = f(f(tileX) * 10), originY = f(f(tileY) * 10);
  const destination = [f(f(to[0]) - originX), f(f(to[1]) - originY), 0];
  let current = [f(clipped.entry[0] - originX), f(clipped.entry[1] - originY), 0];
  let face = mesh.faces.findIndex(indices => sides(indices.map(index => mesh.vertices[index]), current).every(Boolean));
  if (face < 0) return result;
  current[2] = tilePlaneHeight(mesh.normals[face], mesh.constants[face], current);
  for (let count = 0; face >= 0; count++) {
    if (count >= 512) { onWarning?.('Native tile triangle walk exceeded 512 iterations'); return result; }
    const triangle = mesh.faces[face].map(index => mesh.vertices[index]);
    if (count === 0) result.minHeight = result.maxHeight = current[2];
    else includeHeight(result, current[2]);
    const inside = sides(triangle, destination), total = inside.filter(Boolean).length;
    if (total === 0) return result;
    if (total === 3) {
      includeHeight(result, tilePlaneHeight(mesh.normals[face], mesh.constants[face], destination));
      result.status = 1; return result;
    }
    let next = null, neighbor;
    // Native edge iteration is 2,1,0. For one-inside try both candidates;
    // for two-inside the sole missing edge must intersect.
    for (let edge = 2; edge >= 0; edge--) {
      if (inside[edge]) continue;
      next = intersectTileSegments(current, destination, triangle[edge], triangle[(edge + 1) % 3]);
      if (next) { neighbor = mesh.adjacency[face][edge]; break; }
      if (total === 2) return result;
    }
    if (!next) return result;
    current = next; face = neighbor;
    if (!Number.isInteger(face) || face >= mesh.faces.length) throw new Error('Native tile adjacency is invalid');
    // Native checks the iteration limit before accepting a border sentinel.
    if (face < 0 && count + 1 >= 512) { onWarning?.('Native tile triangle walk exceeded 512 iterations'); return result; }
  }
  if (face === TILE_BORDER) { includeHeight(result, current[2]); result.status = 1; }
  return result;
}

// CNWTile real/canonical quarter turns 1402c57d0/1402c56a0.
// Operate in native horizontal coordinates around the tile's own center;
// avoid trigonometric residues on inclusive boundaries.
export function rotateTilePoint(tile, point, toCanonical) {
  if (![tile.x, tile.y, tile.orientation].every(Number.isInteger) || tile.orientation < 0 || tile.orientation > 3)
    throw new Error('Native tile orientation/location is unavailable');
  const originX = f(f(tile.x) * 10), originY = f(f(tile.y) * 10);
  const x = f(f(point[0]) - originX), y = f(f(point[1]) - originY);
  const orientation = tile.orientation;
  let local = [x, y];
  if (orientation !== 0) {
    if (orientation === (toCanonical ? 1 : 3)) local = [y, f(10 - x)];
    else if (orientation === 2) local = [f(10 - x), f(10 - y)];
    else local = [f(10 - y), x];
  }
  return [f(originX + local[0]), f(originY + local[1])];
}

// CNWSTile::ClippedLineSegmentWalkable 1404fd480: inverse tile rotation,
// actual surface query, forward rotation and loaded tile height offset.
export function clippedAreaTileLine(tile, from, to, onWarning = null) {
  if (!tile.mesh) throw new Error('Native area tile surface mesh is unavailable');
  if (!Number.isFinite(tile.heightOffset)) throw new Error('Native tile height offset is unavailable');
  const result = clippedTileSurfaceLine(tile.mesh, tile.x, tile.y,
    rotateTilePoint(tile, from, true), rotateTilePoint(tile, to, true), onWarning);
  return { ...result, entry: result.entry && rotateTilePoint(tile, result.entry, false),
    exit: result.exit && rotateTilePoint(tile, result.exit, false),
    minHeight: f(result.minHeight + f(tile.heightOffset)), maxHeight: f(result.maxHeight + f(tile.heightOffset)) };
}

// NoNonWalkPolysOnTile 1402c3010..1402c382e: native swept rectangle,
// height/bounds rejection, edge intersections, then rectangle-corner test.
// Three inside flags at stack rbp+38/+3c/+40 are only cleared, never
// initialized in the complete native function. Track unknown scratch values
// and reject only results that depend on them; do not invent stack contents.
export function noDeniedTilePolygons(mesh, from, to, low, high, radius, flag, initialInside = [null, null, null],
  { clampRadius = true, intersect = intersectTileSegments, scratchLabel = 'tile' } = {}) {
  if (!mesh.denied) throw new Error('Native denied tile surface geometry is unavailable');
  validateGeometry(mesh.denied.vertices, mesh.denied.faces);
  const [x1, y1] = from.map(f), [x2, y2] = to.map(f);
  low = f(low); high = f(high); radius = f(radius);
  if (!Number.isInteger(flag) || initialInside.length !== 3) throw new Error('Native tile collision flags are unavailable');
  if (clampRadius && flag === 0 && radius > f(.1) && radius <= f(.65)) radius = f(.1);
  if (x1 === x2 && y1 === y2 || low > high) return 1;
  const dx = f(x2 - x1), dy = f(y2 - y1), length = f(Math.sqrt(f(f(dx*dx) + f(dy*dy))));
  const sx = f(f(dx / length) * radius), sy = f(f(dy / length) * radius);
  const rectangle = [[f(x1-sy), f(sx+y1)], [f(f(x2-sy)+sx), f(f(sx+y2)+sy)],
    [f(f(sy+x2)+sx), f(f(y2-sx)+sy)], [f(sy+x1), f(y1-sx)]];
  const quadrant = x2 < x1 ? (y2 < y1 ? 3 : 2) : Number(y1 <= y2);
  const maxX = rectangle[(quadrant+1)&3][0], maxY = rectangle[quadrant][1];
  const minX = rectangle[(quadrant-1)&3][0], minY = rectangle[(quadrant-2)&3][1];
  const inside = [...initialInside];
  let uncertain = false;
  for (const indices of mesh.denied.faces) {
    const triangle = indices.map(index => mesh.denied.vertices[index]);
    if (!triangle.some(v => v[0] <= maxX) || !triangle.some(v => v[1] <= maxY) ||
      !triangle.some(v => v[0] >= minX) || !triangle.some(v => v[1] >= minY) ||
      !triangle.some(v => v[2] <= high) || !triangle.some(v => v[2] >= low)) continue;
    const edges = [1, 1, 1];
    for (let edge = 0; edge < 4; edge++) {
      const a = rectangle[edge], b = rectangle[(edge+1)&3];
      const side = triangle.map(v => f(f(f(v[1]-a[1]) * f(a[0]-b[0])) + f(f(v[0]-a[0]) * f(b[1]-a[1]))) >= 0);
      for (let vertex = 0; vertex < 3; vertex++) {
        if (!side[vertex]) inside[vertex] = 0;
        if (!side[vertex] && !side[(vertex+1)%3]) edges[vertex] = 0;
      }
    }
    for (let vertex = 0; vertex < 3; vertex++) {
      if (inside[vertex] === 1) return 0;
      if (inside[vertex] === null) uncertain = true;
      if (edges[vertex] !== 1) continue;
      for (let edge = 0; edge < 4; edge++) {
        if (intersect([...rectangle[edge], 0], [...rectangle[(edge+1)&3], 0], triangle[vertex], triangle[(vertex+1)%3])) return 0;
      }
    }
    if (sides(triangle, rectangle[0]).every(Boolean)) return 0;
  }
  if (uncertain) throw new Error(`Native ${scratchLabel} collision result depends on uninitialized inside-flag stack state`);
  return 1;
}

// Tile wrapper1404fe040 uses the local rotation helper without the
// translate-back additions of RotateRealToCanonicalTile.
export function noDeniedAreaTilePolygons(tile, from, to, low, high, radius, flag, initialInside) {
  if (!tile.mesh || !Number.isFinite(tile.heightOffset)) throw new Error('Native area tile collision mesh is unavailable');
  const local = point => {
    const x = f(f(point[0]) - f(f(tile.x)*10)), y = f(f(point[1]) - f(f(tile.y)*10));
    if (tile.orientation === 0) return [x,y];
    if (tile.orientation === 1) return [y,f(10-x)];
    if (tile.orientation === 2) return [f(10-x),f(10-y)];
    if (tile.orientation === 3) return [f(10-y),x];
    throw new Error('Native tile orientation is unavailable');
  };
  return noDeniedTilePolygons(tile.mesh, local(from), local(to), f(f(low)-tile.heightOffset), f(f(high)-tile.heightOffset), radius, flag, initialInside);
}

function between(value, a, b) { return value >= Math.min(a, b) && value <= Math.max(a, b); }
function sides([a, b, c], point) {
  return [[a, b], [b, c], [c, a]].map(([u, v]) =>
    f(f(f(v[0] - u[0]) * f(point[1] - u[1])) + f(f(u[1] - v[1]) * f(point[0] - u[0]))) >= 0);
}
function includeHeight(result, height) {
  if (height >= result.maxHeight) result.maxHeight = height;
  else if (height <= result.minHeight) result.minHeight = height;
}
function validateGeometry(vertices, faces) {
  if (!Array.isArray(vertices) || !Array.isArray(faces) || vertices.some(v => v.length !== 3 || !v.every(Number.isFinite)) ||
    faces.some(face => face.length !== 3 || face.some(index => !Number.isInteger(index) || index < 0 || index >= vertices.length)))
    throw new Error('Native tile surface geometry is unavailable or invalid');
}

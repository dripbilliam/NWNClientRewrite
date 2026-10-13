const MAX_WALKMESH_ELEMENTS = 2_000_000;

export function parseWalkmesh(input, walkableSurfaces = null, transform = {}) {
  const text = typeof input === 'string' ? input : new TextDecoder('ascii').decode(input);
  const walkmeshHeader = /(?:^|\n)\s*(?:#MAXWALKMESH\s+ASCII|#MAXDOOR\s+ASCII|#NWMAX\s+(?:WALKMESH|PWKMESH|DWKMESH)\s+ASCII)\b/im.test(text);
  // Some shipped PWKs use the generic model exporter header and arbitrary node names.
  const legacyPlaceable = /(?:^|\n)\s*#MAXMODEL\s+ASCII\b/im.test(text);
  if (!walkmeshHeader && !legacyPlaceable) {
    throw new Error('Unsupported NWN walkmesh format.');
  }

  const lines = text.replaceAll('\r', '').split('\n');
  const vertices = [];
  const triangles = [];
  const tilePosition = transform.position ?? [0, 0, 0];
  const tileAngle = Number.isFinite(transform.angle)
    ? transform.angle
    : (Number(transform.orientation) || 0) * Math.PI / 2;
  let nodePosition = [0, 0, 0];
  let nodeOrientation = [0, 0, 1, 0];
  let nodeVertexStart = 0;
  let nodeName = '';

  for (let lineIndex = 0; lineIndex < lines.length; lineIndex += 1) {
    const line = lines[lineIndex].trim();
    if (!line || line.startsWith('#')) continue;
    const tokens = line.split(/\s+/);
    const command = tokens[0].toLowerCase();

    if (command === 'node') {
      nodeName = tokens[2] ?? '';
      nodePosition = [0, 0, 0];
      nodeOrientation = [0, 0, 1, 0];
      nodeVertexStart = vertices.length;
    } else if (command === 'position') {
      nodePosition = parseVector(tokens, 1, 3, lineIndex + 1);
    } else if (command === 'orientation') {
      nodeOrientation = parseVector(tokens, 1, 4, lineIndex + 1);
    } else if (command === 'verts' || command === 'faces') {
      const count = Number(tokens[1]);
      if (!Number.isInteger(count) || count < 0 || count > MAX_WALKMESH_ELEMENTS) {
        throw new Error(`Invalid WOK ${command} count at line ${lineIndex + 1}.`);
      }

      for (let row = 0; row < count; row += 1) {
        let rowLine = '';
        while (++lineIndex < lines.length) {
          rowLine = lines[lineIndex].trim();
          if (rowLine && !rowLine.startsWith('#')) break;
        }
        if (!rowLine) throw new Error(`Truncated WOK ${command} section.`);
        const values = rowLine.split(/\s+/).map(Number);

        if (command === 'verts') {
          if (values.length < 3 || values.slice(0, 3).some(value => !Number.isFinite(value))) {
            throw new Error(`Invalid WOK vertex at line ${lineIndex + 1}.`);
          }
          const nodeRotated = rotateAxisAngle(values.slice(0, 3), nodeOrientation)
            .map((value, axis) => value + nodePosition[axis]);
          const tileRotated = rotateZ(nodeRotated, tileAngle);
          const nwX = tileRotated[0] + tilePosition[0];
          const nwY = tileRotated[1] + tilePosition[1];
          const nwZ = tileRotated[2] + tilePosition[2];
          vertices.push([nwX, nwZ, -nwY]);
          continue;
        }

        if (values.length < 8 || values.slice(0, 3).some(value => !Number.isInteger(value))) {
          throw new Error(`Invalid WOK face at line ${lineIndex + 1}.`);
        }
        const localIndices = values.slice(0, 3);
        if (localIndices.some(index => index < 0 || nodeVertexStart + index >= vertices.length)) {
          throw new Error(`WOK face index outside the vertex array at line ${lineIndex + 1}.`);
        }
        const indices = localIndices.map(index => nodeVertexStart + index);
        const surfaceType = values[7];
        if (!Number.isInteger(surfaceType) || (walkableSurfaces && !walkableSurfaces[surfaceType])) continue;
        triangles.push({
          vertices: indices.map(index => vertices[index]),
          surfaceType,
          nodeName
        });
      }
    }
  }

  return triangles;
}

// NWN:EE CNWDoorSurfaceMesh::LoadWalkMesh (0x1402cf720) uses these names.
export function parseDoorWalkmesh(input, transform = {}) {
  const triangles = parseWalkmesh(input, null, transform);
  const states = [null, null, null];
  const text = typeof input === 'string' ? input : new TextDecoder('ascii').decode(input);
  for (const match of text.matchAll(/^\s*node\s+trimesh\s+\S*_DWK_wg_(closed|open1|open2)\s*$/gim)) {
    const state = { closed: 0, open1: 1, open2: 2 }[match[1].toLowerCase()];
    states[state] = [];
  }
  for (const triangle of triangles) {
    const match = triangle.nodeName.match(/_DWK_wg_(closed|open1|open2)$/i);
    if (!match) continue;
    const state = { closed: 0, open1: 1, open2: 2 }[match[1].toLowerCase()];
    states[state].push(triangle);
  }
  if (states.every(state => state === null)) throw new Error('DWK has no recognized door collision states.');
  return states;
}

export function parseDoorActionPoints(input, transform = {}) {
  const text = typeof input === 'string' ? input : new TextDecoder('ascii').decode(input);
  const points = [[], [], []];
  const position = transform.position ?? [0, 0, 0];
  for (const node of text.matchAll(/^\s*node\s+dummy\s+\S*_DWK_dp_(closed|open1|open2)_\d+\s*\n([\s\S]*?)^\s*endnode\b/gim)) {
    const value = node[2].match(/^\s*position\s+([^\r\n]+)/im);
    if (!value) continue;
    const local = value[1].trim().split(/\s+/).map(Number);
    if (local.length !== 3 || !local.every(Number.isFinite)) throw new Error('Invalid door action point');
    const rotated = rotateZ(local, transform.angle ?? 0).map((v, axis) => v + position[axis]);
    points[{ closed: 0, open1: 1, open2: 2 }[node[1].toLowerCase()]].push([rotated[0], rotated[2], -rotated[1]]);
  }
  return points;
}

// CNWPlaceableSurfaceMesh::LoadWalkMesh accepts both exporter naming forms.
export function parsePlaceableActionPoints(input, transform = {}) {
  const text = typeof input === 'string' ? input : new TextDecoder('ascii').decode(input);
  const points = [null, null], position = transform.position ?? [0, 0, 0];
  for (const node of text.matchAll(/^\s*node\s+dummy\s+\S*_pwk_(?:use|dp_use_)(01|02)\s*\n([\s\S]*?)^\s*endnode\b/gim)) {
    const value = node[2].match(/^\s*position\s+([^\r\n]+)/im);
    if (!value) continue;
    const local = value[1].trim().split(/\s+/).map(Number);
    if (local.length !== 3 || !local.every(Number.isFinite)) throw new Error('Invalid placeable action point');
    const rotated = rotateZ(local, transform.angle ?? 0).map((v, axis) => v + position[axis]);
    points[Number(node[1]) - 1] = [rotated[0], rotated[2], -rotated[1]];
  }
  return points;
}

export function findWalkableHeight(triangles, x, z, referenceHeight = Infinity, maxDelta = Infinity) {
  let bestHeight = null;
  let bestDistance = Infinity;

  for (const triangle of triangles) {
    const [a, b, c] = triangle.vertices;
    const denominator = (b[2] - c[2]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[2] - c[2]);
    if (Math.abs(denominator) < 1e-8) continue;

    const weightA = ((b[2] - c[2]) * (x - c[0]) + (c[0] - b[0]) * (z - c[2])) / denominator;
    const weightB = ((c[2] - a[2]) * (x - c[0]) + (a[0] - c[0]) * (z - c[2])) / denominator;
    const weightC = 1 - weightA - weightB;
    if (Math.min(weightA, weightB, weightC) < -1e-5) continue;

    const height = weightA * a[1] + weightB * b[1] + weightC * c[1];
    const distance = Number.isFinite(referenceHeight) ? Math.abs(height - referenceHeight) : -height;
    if (distance > maxDelta || distance >= bestDistance) continue;
    bestHeight = height;
    bestDistance = distance;
  }

  return bestHeight;
}

export function moveOnWalkmesh(triangles, position, deltaX, deltaZ, radius, maxStep, obstacles = []) {
  if (![...position, deltaX, deltaZ, radius, maxStep].every(Number.isFinite) || radius < 0 || maxStep < 0) return null;
  const steps = Math.max(1, Math.ceil(Math.hypot(deltaX, deltaZ) / 0.08));
  if (steps > 4096) return null;
  const probes = [[0, 0], ...Array.from({ length: 8 }, (_, index) =>
    [Math.cos(index * Math.PI / 4) * radius, Math.sin(index * Math.PI / 4) * radius])];
  let previous = position;
  for (let step = 1; step <= steps; step += 1) {
    const x = position[0] + deltaX * step / steps;
    const z = position[2] + deltaZ * step / steps;
    const height = findWalkableHeight(triangles, x, z, previous[1], maxStep);
    if (height === null) return null;
    const destination = [x, height, z];
    if (probes.some(([dx, dz]) => !isSupportedSegment(triangles,
      [previous[0] + dx, previous[1], previous[2] + dz], [x + dx, height, z + dz], maxStep))) return null;
    if (collidesWithObjectWalkmeshes(obstacles, previous, destination, radius)) return null;
    previous = destination;
  }
  return previous;
}

export function collidesWithObjectWalkmeshes(obstacles, start, end, radius, bodyHeight = 1.35) {
  // Clip to the body's vertical span, then sweep its full horizontal disk.
  // This also detects stationary overlap and grazing diagonal/short walls.
  const minimum = Math.min(start[1], end[1]) + 0.02;
  const maximum = Math.max(start[1], end[1]) + bodyHeight - 0.02;
  for (const triangle of obstacles) {
    const polygon = clipHeight(clipHeight(triangle.vertices, minimum, true), maximum, false);
    if (!polygon.length) continue;
    if (pointInPolygon(start, polygon) || pointInPolygon(end, polygon)) return true;
    for (let index = 0; index < polygon.length; index += 1) {
      if (segmentDistanceSquared(start, end, polygon[index], polygon[(index + 1) % polygon.length])
        < Math.max(radius * radius, 1e-12)) return true;
    }
  }
  return false;
}

function isSupportedSegment(triangles, start, end, maxStep) {
  const intervals = [];
  for (const { vertices: [a, b, c] } of triangles) {
    const denominator = (b[2] - c[2]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[2] - c[2]);
    if (Math.abs(denominator) < 1e-8) continue;
    const weights = point => {
      const wa = ((b[2] - c[2]) * (point[0] - c[0]) + (c[0] - b[0]) * (point[2] - c[2])) / denominator;
      const wb = ((c[2] - a[2]) * (point[0] - c[0]) + (a[0] - c[0]) * (point[2] - c[2])) / denominator;
      return [wa, wb, 1 - wa - wb];
    };
    const from = weights(start);
    const to = weights(end);
    let low = 0;
    let high = 1;
    // Each barycentric coordinate is linear along the segment.
    const constrain = (initial, final) => {
      const difference = final - initial;
      if (Math.abs(difference) < 1e-12) { if (initial < -1e-7) high = -1; return; }
      const crossing = (-1e-7 - initial) / difference;
      if (difference > 0) low = Math.max(low, crossing);
      else high = Math.min(high, crossing);
    };
    for (let axis = 0; axis < 3; axis += 1) constrain(from[axis], to[axis]);
    const floor = w => w[0] * a[1] + w[1] * b[1] + w[2] * c[1];
    const fromDelta = floor(from) - start[1];
    const toDelta = floor(to) - end[1];
    constrain(maxStep - fromDelta, maxStep - toDelta);
    constrain(maxStep + fromDelta, maxStep + toDelta);
    if (low <= high) intervals.push([low, high]);
  }
  intervals.sort((a, b) => a[0] - b[0]);
  let covered = 0;
  for (const [low, high] of intervals) {
    if (low > covered + 1e-7) return false;
    covered = Math.max(covered, high);
    if (covered >= 1 - 1e-7) return true;
  }
  return false;
}

function clipHeight(polygon, height, above) {
  const clipped = [];
  for (let index = 0; index < polygon.length; index += 1) {
    const a = polygon[index];
    const b = polygon[(index + 1) % polygon.length];
    const insideA = above ? a[1] >= height : a[1] <= height;
    const insideB = above ? b[1] >= height : b[1] <= height;
    if (insideA) clipped.push(a);
    if (insideA !== insideB) {
      const t = (height - a[1]) / (b[1] - a[1]);
      clipped.push(a.map((value, axis) => value + t * (b[axis] - value)));
    }
  }
  return clipped;
}

function pointInPolygon(point, polygon) {
  let inside = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const a = polygon[i];
    const b = polygon[j];
    if ((a[2] > point[2]) !== (b[2] > point[2]) &&
      point[0] < (b[0] - a[0]) * (point[2] - a[2]) / (b[2] - a[2]) + a[0]) inside = !inside;
  }
  return inside;
}

function segmentDistanceSquared(a, b, c, d) {
  const orient = (p, q, r) => (q[0] - p[0]) * (r[2] - p[2]) - (q[2] - p[2]) * (r[0] - p[0]);
  if (orient(a, b, c) * orient(a, b, d) < 0 && orient(c, d, a) * orient(c, d, b) < 0) return 0;
  const pointDistance = (p, q, r) => {
    const dx = r[0] - q[0];
    const dz = r[2] - q[2];
    const length = dx * dx + dz * dz;
    const t = length ? Math.max(0, Math.min(1, ((p[0] - q[0]) * dx + (p[2] - q[2]) * dz) / length)) : 0;
    return (p[0] - q[0] - t * dx) ** 2 + (p[2] - q[2] - t * dz) ** 2;
  };
  return Math.min(pointDistance(a, c, d), pointDistance(b, c, d), pointDistance(c, a, b), pointDistance(d, a, b));
}

function parseVector(tokens, start, length, lineNumber) {
  const values = tokens.slice(start, start + length).map(Number);
  if (values.length !== length || values.some(value => !Number.isFinite(value))) {
    throw new Error(`Invalid WOK transform at line ${lineNumber}.`);
  }
  return values;
}

function rotateAxisAngle(vector, orientation) {
  const [axisX, axisY, axisZ, angle] = orientation;
  const axisLength = Math.hypot(axisX, axisY, axisZ);
  if (axisLength < 1e-8 || Math.abs(angle) < 1e-8) return vector;
  const x = axisX / axisLength;
  const y = axisY / axisLength;
  const z = axisZ / axisLength;
  const cosine = Math.cos(angle);
  const sine = Math.sin(angle);
  const dot = x * vector[0] + y * vector[1] + z * vector[2];
  const cross = [
    y * vector[2] - z * vector[1],
    z * vector[0] - x * vector[2],
    x * vector[1] - y * vector[0]
  ];
  return vector.map((value, index) => value * cosine + cross[index] * sine + [x, y, z][index] * dot * (1 - cosine));
}

function rotateZ(vector, angle) {
  const cosine = Math.cos(angle);
  const sine = Math.sin(angle);
  return [
    vector[0] * cosine - vector[1] * sine,
    vector[0] * sine + vector[1] * cosine,
    vector[2]
  ];
}


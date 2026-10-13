import { findWalkableHeight, moveOnWalkmesh } from './walkmesh.js';

const distance = (a, b) => Math.hypot(a[0] - b[0], a[2] - b[2]);
const key = point => point.map(v => Math.round(v * 10000)).join(':');
const boundsCache = new WeakMap();
function bounds(triangle) {
  if (!boundsCache.has(triangle)) boundsCache.set(triangle, [
    Math.min(...triangle.vertices.map(v => v[0])), Math.max(...triangle.vertices.map(v => v[0])),
    Math.min(...triangle.vertices.map(v => v[2])), Math.max(...triangle.vertices.map(v => v[2]))
  ]);
  return boundsCache.get(triangle);
}

// A bounded local replacement planner, not a reconstruction of NWN's pathfinder.
export class WalkmeshNavigator {
  constructor(triangles, { radius = 0.22, maxStep = 0.9 } = {}) {
    Object.assign(this, { triangles, radius, maxStep });
    this.cells = new Map();
    for (const triangle of triangles) {
      const [x0,x1,z0,z1] = bounds(triangle);
      for (let x=Math.floor(x0/10);x<=Math.floor(x1/10);x++) for(let z=Math.floor(z0/10);z<=Math.floor(z1/10);z++) {
        const id = `${x}:${z}`;
        if (!this.cells.has(id)) this.cells.set(id,[]);
        this.cells.get(id).push(triangle);
      }
    }
    this.nodes = triangles.map(({ vertices }) => ({ point: [0, 1, 2].map(axis => vertices.reduce((sum, v) => sum + v[axis], 0) / 3), links: [] }));
    this.faceNodes = this.nodes.map((_, index) => [index]);
    const edges = new Map();
    triangles.forEach(({ vertices }, face) => {
      for (let edge = 0; edge < 3; edge++) {
        const a = vertices[edge], b = vertices[(edge + 1) % 3];
        const edgeKey = [key(a), key(b)].sort().join('|');
        if (!edges.has(edgeKey)) edges.set(edgeKey, { faces: [], a, b });
        edges.get(edgeKey).faces.push(face);
      }
    });
    for (const { faces, a, b } of edges.values()) if (faces.length > 1) {
      for (const fraction of [0.25, 0.5, 0.75]) {
        const portal = this.nodes.length;
        this.nodes.push({ point: a.map((v, axis) => v + (b[axis] - v) * fraction), links: [] });
        for (const face of faces) this.faceNodes[face].push(portal);
      }
    }
    // Portal-to-portal paths can pass a blocked face centroid. Validate every
    // candidate edge with the capsule sweep when searching.
    for (const ids of this.faceNodes) for (const id of ids) {
      this.nodes[id].links = [...new Set([...this.nodes[id].links, ...ids.filter(other => other !== id)])];
    }
  }
  corridor(a,b,obstacles) {
    const margin = this.radius + 0.01;
    const x0 = Math.min(a[0],b[0])-margin, x1 = Math.max(a[0],b[0])+margin;
    const z0 = Math.min(a[2],b[2])-margin, z1 = Math.max(a[2],b[2])+margin;
    const overlaps = triangle => { const box = bounds(triangle); return box[0]<=x1 && box[1]>=x0 && box[2]<=z1 && box[3]>=z0; };
    const nearby = new Set();
    for(let x=Math.floor(x0/10);x<=Math.floor(x1/10);x++) for(let z=Math.floor(z0/10);z<=Math.floor(z1/10);z++) {
      for(const triangle of this.cells.get(`${x}:${z}`) ?? []) if (overlaps(triangle)) nearby.add(triangle);
    }
    return { triangles:[...nearby], obstacles:obstacles.filter(overlaps) };
  }
  supported(point, obstacles) {
    const local = this.corridor(point,point,obstacles);
    return moveOnWalkmesh(local.triangles, point, 0, 0, this.radius, this.maxStep, local.obstacles);
  }
  segment(a, b, obstacles) {
    const local = this.corridor(a,b,obstacles);
    const end = moveOnWalkmesh(local.triangles, a, b[0] - a[0], b[2] - a[2], this.radius, this.maxStep, local.obstacles);
    return end && Math.abs(end[1] - b[1]) < 0.2;
  }
  faceLinks(point) {
    return [...new Set(this.triangles.flatMap((triangle, index) => {
      const height = findWalkableHeight([triangle], point[0], point[2], point[1], 0.2);
      return height === null ? [] : this.faceNodes[index];
    }))];
  }
  path(start, destination, obstacles = []) {
    const goal = this.supported(destination, obstacles);
    if (!goal || !this.supported(start, obstacles)) return null;
    if (this.segment(start, goal, obstacles)) return [goal];
    const nodes = [...this.nodes, { point: start, links: this.faceLinks(start) }, { point: goal, links: [] }];
    const first = nodes.length - 2, last = nodes.length - 1;
    const goals = new Set(this.faceLinks(goal));
    const pending = new Set([first]), cost = new Map([[first, 0]]), previous = new Map(), visited = new Set();
    let expansions = 0;
    while (pending.size && expansions++ < 12000) {
      let current, score = Infinity;
      for (const id of pending) {
        const candidate = cost.get(id) + distance(nodes[id].point, goal);
        if (candidate < score) { current = id; score = candidate; }
      }
      pending.delete(current);
      if (current === last) {
        const route = [];
        for (let id = last; id !== first; id = previous.get(id)) route.unshift(nodes[id].point);
        // Remove needless portal/centroid detours only when swept support is clear.
        const smoothed = []; let point = start;
        while (route.length) {
          let end = route.length - 1;
          while (end > 0 && !this.segment(point, route[end], obstacles)) end--;
          point = route[end]; smoothed.push(point); route.splice(0, end + 1);
        }
        return smoothed;
      }
      visited.add(current);
      const links = goals.has(current) ? [...nodes[current].links, last] : nodes[current].links;
      for (const next of links) {
        if (visited.has(next) || !this.segment(nodes[current].point, nodes[next].point, obstacles)) continue;
        const candidate = cost.get(current) + distance(nodes[current].point, nodes[next].point);
        if (candidate >= (cost.get(next) ?? Infinity)) continue;
        cost.set(next, candidate); previous.set(next, current); pending.add(next);
      }
    }
    return null;
  }
  approach(start, points, obstacles) {
    const sorted = [...points].sort((a, b) => distance(start, a) - distance(start, b));
    for (const point of sorted) {
      const path = this.path(start, point, obstacles);
      if (path) return path;
    }
    return null;
  }
}

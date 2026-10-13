import { doorUsePoints } from './door_use.js';
import { activeObjectCollisions } from './door.js';
import { findWalkableHeight, moveOnWalkmesh } from './walkmesh.js';

// Native AIActionJumpToObject uses a door action point behind its facing,
// offsets by twice the actor radius, then calls CNWSArea::ComputeSafeLocation.
// The desired position/facing are mapped; the bounded safe-location search is
// still our walkmesh implementation, not a claim of native pathfinder parity.
export function resolveJumpSpawn(destination, actor, triangles, collisions) {
  let desired = [...destination.position], direction = null;
  if (destination.kind === 'door') {
    const facing = [-Math.sin(destination.bearing), 0, -Math.cos(destination.bearing)];
    const query = destination.position.map((v, axis) => v - facing[axis]);
    let distance = Infinity, chosen = destination.position;
    for (const point of doorUsePoints(destination)) {
      if (findWalkableHeight(triangles, point[0], point[2], point[1], 0.9) === null) continue;
      const score = point.reduce((sum, v, axis) => sum + (v - query[axis]) ** 2, 0);
      if (score <= distance) { distance = score; chosen = point; }
    }
    desired = chosen.map((v, axis) => Math.fround(v - facing[axis] * actor.radius * 2));
    direction = desired.map((v, axis) => v - destination.position[axis]);
  } else if (destination.kind === 'waypoint') direction = [-Math.sin(destination.bearing), 0, -Math.cos(destination.bearing)];
  const obstacles = activeObjectCollisions(collisions);
  const valid = (x, z) => {
    const height = findWalkableHeight(triangles, x, z, desired[1], 0.9);
    return height === null ? null : moveOnWalkmesh(triangles, [x, height, z], 0, 0, actor.radius, 0.9, obstacles);
  };
  let spawn = valid(desired[0], desired[2]);
  for (let radius = 0.25; !spawn && radius <= 2; radius += 0.25) {
    for (let angle = 0; !spawn && angle < 16; angle++) spawn = valid(desired[0] + Math.cos(angle * Math.PI / 8) * radius, desired[2] + Math.sin(angle * Math.PI / 8) * radius);
  }
  if (!spawn) throw new Error(`No safe spawn beside ${destination.tag || destination.id}`);
  return { position: spawn, bearing: direction && Math.hypot(direction[0], direction[2]) > 0 ? Math.atan2(-direction[0], -direction[2]) : actor.bearing ?? 0, desired };
}

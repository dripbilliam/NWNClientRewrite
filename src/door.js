import { RESOURCE_TYPE } from './resource_archive.js';
import { runtimeDiagnostics } from './runtime_diagnostics.js';
import { collidesWithObjectWalkmeshes, parseDoorActionPoints, parsePlaceableActionPoints, parseDoorWalkmesh, parseWalkmesh } from './walkmesh.js';

export async function loadAreaCollisions(area, resolver) {
  const placeables = [];
  const doors = [];
  const missing = [];
  const placeableActionPoints = new Map();
  for (const [kind, objects, type] of [
    ['placeable', area.placeables, RESOURCE_TYPE.PWK], ['door', area.doors, RESOURCE_TYPE.DWK]
  ]) {
    for (const [index, placement] of objects.entries()) {
      const transform = { position: [placement.x, placement.y, placement.z], angle: placement.bearing };
      let states = null;
      let actionPoints = [[], [], []];
      try {
        const bytes = await resolver.getResource(placement.model, type);
        if (kind === 'door') { states = parseDoorWalkmesh(bytes, transform); actionPoints = parseDoorActionPoints(bytes, transform); }
        else {
          const sourceKey = `${area.resRef}:placeable:${placement.sourceIndex ?? index}`;
          placeables.push(...parseWalkmesh(bytes, null, transform).map(face => ({ ...face, ownerSourceKey: sourceKey })));
          placeableActionPoints.set(sourceKey, parsePlaceableActionPoints(bytes, transform));
        }
      } catch (error) {
        runtimeDiagnostics.error(error, 'scene.object-walkmesh-unavailable', { area: area.resRef, model: placement.model, tag: placement.tag, sourceKey: `${area.resRef}:${kind}:${placement.sourceIndex ?? index}` });
        missing.push({ kind, model: placement.model, tag: placement.tag, reason: error.message });
      }
      if (kind === 'door') doors.push({
        ...placement, sourceKey: `${area.resRef}:door:${placement.sourceIndex ?? index}`, states, actionPoints, object: null,
        position: [placement.x, placement.z, -placement.y]
      });
    }
  }
  return { placeables, doors, missing, placeableActionPoints };
}

export function doorCollision(door, state = door.animationState) {
  if (door.animating && state === door.animationState && door.transitionCollision) return door.transitionCollision;
  if (state === 3) return [];
  return door.states?.[state] ?? door.states?.[0] ?? [];
}

export function activeObjectCollisions(collisions) {
  return [...collisions.placeables, ...collisions.doors.flatMap(door => doorCollision(door))];
}

export function nearestDoor(doors, position, range = 2.5) {
  let nearest = null;
  let distance = range;
  for (const door of doors) {
    if (door.animationState === 3 || Math.abs(position[1] - door.position[1]) > 1.5) continue;
    const current = Math.hypot(position[0] - door.position[0], position[2] - door.position[2]);
    if (current <= distance) { nearest = door; distance = current; }
  }
  return nearest;
}

export function toggleDoor(door, playerPosition, radius = 0.22) {
  return setDoorState(door, door.animationState === 0 ? 1 : 0, playerPosition, radius);
}

export function setDoorState(door, next, playerPosition, radius = 0.22) {
  if (door.animating) return { changed: false, message: 'Door animation is still playing' };
  if (door.animationState === 3) return { changed: false, message: 'Door is destroyed' };
  if (door.animationState === next) return { changed: false, message: next ? 'Door is already open' : 'Door is already closed' };
  if (next && door.locked) return { changed: false, message: 'Door is locked' };
  if (!door.states?.[next]) return { changed: false, message: 'Door collision state unavailable' };
  if (collidesWithObjectWalkmeshes(door.states[next], playerPosition, playerPosition, radius)) {
    return { changed: false, message: 'Step away from the door before changing its state' };
  }
  door.animationState = next;
  return { changed: true, message: next ? 'Door opened' : 'Door closed' };
}

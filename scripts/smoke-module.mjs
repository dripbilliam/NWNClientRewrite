// Assets are read from the user's install; only diagnostic JSON is emitted.
import assert from 'node:assert/strict';
import { openLocalModule } from './local-module.mjs';
import { loadAreaWalkmesh, parseAreaModule } from '../src/area.js';
import { parseGff } from '../src/gff.js';
import { activeObjectCollisions, doorCollision, loadAreaCollisions, toggleDoor } from '../src/door.js';
import { collidesWithObjectWalkmeshes, moveOnWalkmesh } from '../src/walkmesh.js';

const [install, modulePath, ...areas] = process.argv.slice(2);
if (!install || !modulePath) {
  console.error('Usage: node scripts/smoke-module.mjs <install> <module> [area ...]');
  process.exit(1);
}
const resolver = await openLocalModule(install, modulePath, process.env.NWN_HAK_PATH);
assert.equal(resolver.missingHaks.length, 0, `Missing HAKs: ${resolver.missingHaks.join(', ')}`);
const entry = parseGff(resolver.module.entries.get('module:2014'), 'IFO ').root;
for (const name of [...new Set([entry.Mod_Entry_Area, ...areas])]) {
  const area = await parseAreaModule(name, resolver);
  const walk = await loadAreaWalkmesh(area, resolver);
  const collisions = await loadAreaCollisions(area, resolver);
  assert.ok(walk.triangles.length > 0, `${name}: no walkable faces`);
  assert.equal(walk.missing.length, 0, `${name}: missing tile walkmeshes`);
  const testedDoors = [];
  const eligibleDoors = collisions.doors.filter(door => !door.locked && door.animationState === 0 && door.states?.[1]);
  for (const door of eligibleDoors) {
    // Find a route through the closed leaf which the opened leaf clears.
    let route = null;
    for (let x = -2; x <= 2 && !route; x += 0.5) {
      for (let y = -2; y <= 2 && !route; y += 0.5) {
        const point = (dx, dy) => [
          door.x + dx * Math.cos(door.bearing) - dy * Math.sin(door.bearing),
          door.z,
          -(door.y + dx * Math.sin(door.bearing) + dy * Math.cos(door.bearing))
        ];
        for (const [dx, dy] of [[1, 0], [0, 1]]) {
          const start = point(x - dx, y - dy), end = point(x + dx, y + dy);
          if (collidesWithObjectWalkmeshes(doorCollision(door), start, end, 0.22) &&
              !collidesWithObjectWalkmeshes(doorCollision(door, 1), start, end, 0.22) &&
              !collidesWithObjectWalkmeshes(doorCollision(door), start, start, 0.22)) {
            route = { start, end };
            break;
          }
        }
      }
    }
    if (!route) continue;
    assert.equal(toggleDoor(door, route.start).changed, true);
    assert.equal(collidesWithObjectWalkmeshes(doorCollision(door), route.start, route.end, 0.22), false);
    assert.equal(toggleDoor(door, route.start).changed, true);
    assert.equal(collidesWithObjectWalkmeshes(doorCollision(door), route.start, route.end, 0.22), true);
    testedDoors.push(door.tag || door.model);
  }
  if (eligibleDoors.length) assert.ok(testedDoors.length > 0, `${name}: no eligible door collision route verified`);
  let movementChecks = 0;
  const obstacles = activeObjectCollisions(collisions);
  const began = performance.now();
  for (const triangle of walk.triangles.slice(0, 100)) {
    const center = [0, 1, 2].map(axis => triangle.vertices.reduce((sum, v) => sum + v[axis], 0) / 3);
    if (moveOnWalkmesh(walk.triangles, center, 0.05, 0, 0.22, 0.9, obstacles)) movementChecks += 1;
  }
  assert.ok(movementChecks > 0, `${name}: no sampled player movement accepted`);
  console.log(JSON.stringify({ area: name, tiles: area.tiles.length, walkableFaces: walk.triangles.length,
    objectCollisionFaces: obstacles.length, missingObjectWalkmeshes: collisions.missing.length,
    doors: collisions.doors.length, testedDoors, movementChecks, sampleMilliseconds: Math.round(performance.now() - began) }));
}

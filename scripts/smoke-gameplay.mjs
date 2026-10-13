// Read installed module resources; never modify or copy game assets.
import assert from 'node:assert/strict';
import { openLocalModule } from './local-module.mjs';
import { parseAreaModule, loadAreaWalkmesh } from '../src/area.js';
import { loadAreaCollisions, activeObjectCollisions } from '../src/door.js';
import { WalkmeshNavigator } from '../src/navigation.js';
import { WorldObjects } from '../src/world_objects.js';
import { ActionQueue } from '../src/action_queue.js';
import { createDoorUseHandler, doorUsePoints } from '../src/door_use.js';
import { moveOnWalkmesh } from '../src/walkmesh.js';

const [install, modulePath, ...areas] = process.argv.slice(2);
if (!install || !modulePath) throw new Error('Usage: node scripts/smoke-gameplay.mjs <install> <module> [area ...]');
const resolver = await openLocalModule(install,modulePath,process.env.NWN_HAK_PATH);
for (const name of areas.length ? areas : ['angmarshouse','brogansarm']) {
  const area = await parseAreaModule(name,resolver), walk = await loadAreaWalkmesh(area,resolver);
  const collisions = await loadAreaCollisions(area,resolver), registry = new WorldObjects(0);
  for (const door of collisions.doors) registry.add('door',door.sourceKey,door);
  const actor = registry.add('player',`${name}:player`,{ position: [0,0,0] });
  const planner = new WalkmeshNavigator(walk.triangles), events = [], checked = [];
  const queue = new ActionQueue({ registry, actor, handlers: { door: createDoorUseHandler() },
    navigate: points => planner.approach(actor.position,points,activeObjectCollisions(collisions)),
    move: point => {
      const end = moveOnWalkmesh(walk.triangles,actor.position,point[0]-actor.position[0],point[2]-actor.position[2],0.22,0.9,activeObjectCollisions(collisions));
      if (!end) return 'blocked'; actor.position.splice(0,3,...end); return 'arrived';
    },
    inRange: (_target,points,range) => points.some(p => Math.hypot(p[0]-actor.position[0],p[2]-actor.position[2]) <= range),
    onEvent: event => events.push(event)
  });
  for (const door of collisions.doors.filter(d => d.animationState === 0 && !d.locked && d.usable && d.states?.[1] && d.states?.[2])) {
    const obstacles = activeObjectCollisions(collisions);
    let start = null;
    for (const point of doorUsePoints(door)) {
      for (const [dx,dz] of [[0,-2],[0,2],[-2,0],[2,0]]) {
        const candidate = moveOnWalkmesh(walk.triangles,[point[0]+dx,point[1],point[2]+dz],0,0,0.22,0.9,obstacles);
        if (candidate && planner.approach(candidate,[point],obstacles)) { start = candidate; break; }
      }
      if (start) break;
    }
    if (!start) continue;
    actor.position.splice(0,3,...start); events.length = 0;
    queue.use(door.id);
    assert.equal(door.animationState,0,'Click itself must not change state');
    for (let tick=0;tick<100 && queue.current;tick++) queue.update(0.05);
    assert.equal(queue.history.at(-1).phase,'complete',`${door.tag}: ${queue.history.at(-1).message}`);
    assert.ok(door.animationState === 1 || door.animationState === 2);
    assert.equal(events.length,1); assert.equal(events[0].type,'door.stateChanged');
    const openedState = door.animationState;
    events.length = 0; queue.request(door.id,'close');
    for (let tick=0;tick<100 && queue.current;tick++) queue.update(0.05);
    assert.equal(queue.history.at(-1).phase,'complete',`${door.tag}: ${queue.history.at(-1).message}`);
    assert.equal(door.animationState,0); assert.equal(events.length,1);
    checked.push({ tag: door.tag, openedState, closedState:door.animationState, clickScript: door.scripts.click, actionPoints: door.actionPoints.map(p=>p.length) });
  }
  assert.ok(checked.length,`${name}: no door approach/use verified`);
  console.log(JSON.stringify({ area:name, objects:registry.objects.size, checked }));
}

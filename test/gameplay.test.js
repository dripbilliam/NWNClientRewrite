import assert from 'node:assert/strict';
import test from 'node:test';
import * as THREE from 'three';
import { WorldObjects } from '../src/world_objects.js';
import { pickedWorldObject } from '../src/world_picking.js';
import { ActionQueue } from '../src/action_queue.js';
import { createDoorUseHandler, doorOpeningSide, doorUsePoints } from '../src/door_use.js';
import { WalkmeshNavigator } from '../src/navigation.js';
import { parseDoorActionPoints } from '../src/walkmesh.js';

const floor = (x0, x1, z0, z1, y = 0) => {
  const a = [x0,y,z0], b = [x1,y,z0], c = [x0,y,z1], d = [x1,y,z1];
  return [{ vertices: [a,b,c] }, { vertices: [b,d,c] }];
};
const wall = (x,z0,z1) => [{ vertices: [[x,0,z0],[x,2,z0],[x,0,z1]] }, { vertices: [[x,2,z0],[x,2,z1],[x,0,z1]] }];
function fixture() {
  const registry = new WorldObjects(10);
  const actor = registry.add('player', 'player', { position: [0,0,-4] });
  const door = registry.add('door', 'door', { tag: 'Door', position: [0,0,0], bearing: 0, animationState: 0,
    usable: true, locked: false, states: [[],[],[]], actionPoints: [[[0,0,-1]], [[0,0,-1]], [[0,0,1]]] });
  const events = [], statuses = [];
  const queue = new ActionQueue({ registry, actor, handlers: { door: createDoorUseHandler() },
    navigate: points => points,
    move: point => { actor.position.splice(0,3,...point); return 'arrived'; },
    inRange: (_target, points, range) => points.some(p => Math.hypot(p[0]-actor.position[0],p[2]-actor.position[2]) <= range),
    onStatus: message => statuses.push(message),
    onEvent: event => { events.push(event); if (event.type === 'door.stateChanged') door.animating = true; }
  });
  return { registry, actor, door, queue, events, statuses };
}

test('object identities, duplicate tags and render ownership share simulation records', () => {
  const registry = new WorldObjects(10), render = new THREE.Group(), record = { tag: 'Door' };
  assert.equal(registry.add('door','one',record,render), record);
  registry.add('door','two',{ tag: 'Door' });
  assert.deepEqual(registry.byTag('Door').map(object => object.id), [1,0]);
  assert.equal(render.userData.worldObjectId,0);
  assert.throws(() => registry.add('door','one',{}), /Duplicate/);
});

test('picking respects visible scenery occlusion and parent object ownership', () => {
  const root = new THREE.Group(), registry = new WorldObjects(10);
  const owner = new THREE.Group(); root.add(owner);
  const door = new THREE.Mesh(new THREE.BoxGeometry(),new THREE.MeshBasicMaterial()); owner.add(door);
  registry.add('door','door',{},owner);
  const blocker = new THREE.Mesh(new THREE.BoxGeometry(),new THREE.MeshBasicMaterial()); blocker.position.z = 2; root.add(blocker);
  const ray = new THREE.Raycaster(new THREE.Vector3(0,0,5),new THREE.Vector3(0,0,-1));
  assert.equal(pickedWorldObject(ray,root,registry).object,null);
  blocker.visible = false;
  assert.equal(pickedWorldObject(ray,root,registry).object.id,0);
  blocker.visible = true; blocker.userData.ignoreWorldPicking = true;
  assert.equal(pickedWorldObject(ray,root,registry).object.id,0);
  owner.visible = false;
  assert.equal(pickedWorldObject(ray,root,registry),null);
});

test('opened door remains targetable at its doorway but cannot be picked through a wall', () => {
  const root = new THREE.Group(), registry = new WorldObjects(10), owner = new THREE.Group(); root.add(owner);
  const leaf = new THREE.Mesh(new THREE.BoxGeometry(),new THREE.MeshBasicMaterial()); leaf.position.x = 3; owner.add(leaf);
  const record = registry.add('door','door',{object:owner,pickBounds:{min:[-0.5,-0.5,-0.1],max:[0.5,0.5,0.1]}},owner);
  const ray = new THREE.Raycaster(new THREE.Vector3(0,0,5),new THREE.Vector3(0,0,-1));
  assert.equal(pickedWorldObject(ray,root,registry).object,record);
  const wall = new THREE.Mesh(new THREE.BoxGeometry(),new THREE.MeshBasicMaterial()); wall.position.z=2;root.add(wall);
  assert.equal(pickedWorldObject(ray,root,registry).object,null);
  wall.visible=false;owner.visible=false;
  assert.equal(pickedWorldObject(ray,root,registry),null);
});

test('player preview is selectable for a radial without intercepting default world use', () => {
  const root = new THREE.Group(), registry = new WorldObjects(10), player = new THREE.Group();
  player.userData.worldPickingPlayer = true;
  player.add(new THREE.Mesh(new THREE.BoxGeometry(),new THREE.MeshBasicMaterial())); root.add(player);
  registry.add('player','actor',{},player);
  const ray = new THREE.Raycaster(new THREE.Vector3(0,0,5),new THREE.Vector3(0,0,-1));
  assert.equal(pickedWorldObject(ray,root,registry),null);
  assert.equal(pickedWorldObject(ray,root,registry,{includePlayer:true}).object.id,0);
});

test('use approaches before changing state, rejects duplicate requests and waits for animation', () => {
  const { queue, door, events, actor } = fixture();
  assert.equal(queue.use(door.id),true);
  assert.equal(actor.currentActionId,5);
  assert.equal(queue.use(door.id),false);
  queue.update(0.1);
  assert.equal(actor.currentActionId,0);
  assert.equal(door.animationState,0); assert.equal(events.length,0);
  queue.update(0.1);
  assert.equal(door.animationState,1); assert.equal(events.length,1);
  assert.equal(queue.current.phase,'settling');
  assert.equal(actor.currentActionId,5);
  queue.update(0.1); assert.equal(events.length,1);
  door.animating = false; queue.update(0.1);
  assert.equal(queue.current,null); assert.equal(queue.history[0].phase,'complete');
  assert.equal(actor.currentActionId,65535);
});

test('cancellation and blocked routes leave the target state unchanged', () => {
  const f = fixture(); f.queue.use(f.door.id); f.queue.cancel(); f.queue.update(1);
  assert.equal(f.events.length,0); assert.equal(f.door.animationState,0);
  f.queue.navigate = () => null; f.queue.use(f.door.id); f.queue.update(1);
  assert.equal(f.queue.history.at(-1).phase,'failed');
  f.queue.navigate = points => points; f.queue.move = () => 'blocked'; f.queue.use(f.door.id); f.queue.update(1);
  assert.match(f.queue.history.at(-1).message,/blocked/);
});

test('locks are rechecked after approach and dispatch failure events without opening', () => {
  const f = fixture(); f.queue.use(f.door.id); f.queue.update(0.1); f.door.locked = true;
  f.door.scripts = { failToOpen: 'locked_event' }; f.queue.update(0.1);
  assert.equal(f.door.animationState,0);
  assert.equal(f.door.lastFailedToOpenBy,f.actor.id);
  assert.equal(f.events[0].type,'door.failedToOpen');
  assert.equal(f.events[0].script,'locked_event');
  assert.equal(f.queue.history.at(-1).phase,'failed');
});

test('queued intent does not reverse a state changed by another action', () => {
  const f = fixture(); f.queue.use(f.door.id); f.queue.update(0.1);
  f.door.animationState = 1; f.queue.update(0.1);
  assert.equal(f.door.animationState,1); assert.equal(f.events.length,0);
  assert.equal(f.queue.history.at(-1).phase,'complete');
});

test('invalid area targets and unsupported object actions fail explicitly', () => {
  const f = fixture(); const npc = f.registry.add('creature','npc',{});
  f.queue.use(f.door.id);
  assert.equal(f.queue.use(npc.id),false);
  assert.equal(f.queue.current,null);
  f.queue.use(f.door.id); f.door.areaId = 11; f.queue.update(1);
  assert.match(f.queue.history.at(-1).message,/no longer/);
});

test('linked doors default to traversal but explicit close works with links and custom scripts', () => {
  const { actor, door } = fixture(), handler = createDoorUseHandler();
  actor.position = [0,0,-1]; door.animationState = 1; door.linkedTo = 'exit';
  assert.equal(handler.intent(door),'transition');
  assert.equal(handler.execute(door,actor,handler.intent(door)).events[0].type,'door.clicked');
  assert.equal(door.animationState,1);
  door.scripts = { click: 'custom_click', closed: 'on_closed' };
  const result = handler.execute(door,actor,'close');
  assert.equal(result.ok,true); assert.equal(door.animationState,0);
  assert.equal(result.events[0].script,'on_closed');
  assert.equal(door.linkedTo,'exit');
});

test('explicit close uses approach/state/settle lifecycle for both opened sides', () => {
  for (const state of [1,2]) {
    const f = fixture(); f.door.animationState = state; f.door.linkedTo = 'exit';
    assert.equal(f.queue.request(f.door.id,'close'),true);
    assert.equal(f.queue.request(f.door.id,'close'),false);
    f.queue.update(0.1); assert.equal(f.door.animationState,state);
    f.queue.update(0.1); assert.equal(f.door.animationState,0);
    assert.equal(f.events.length,1); assert.equal(f.events[0].previousState,state);
    assert.equal(f.queue.current.phase,'settling');
    f.door.animating = false; f.queue.update(0.1);
    assert.equal(f.queue.history.at(-1).phase,'complete');
    assert.equal(f.queue.request(f.door.id,'attack'),false);
    assert.equal(f.queue.current,null);
  }
});

test('DWK use points rotate into world coordinates and opening side follows facing', () => {
  const points = parseDoorActionPoints('node dummy 01_DWK_dp_closed_01\nposition 2 0 3\nendnode\n', { position: [10,20,4], angle: Math.PI / 2 });
  assert.deepEqual(points[0][0],[10,7,-22]);
  const { door } = fixture();
  assert.equal(doorOpeningSide(door,[0,0,-1]),1);
  assert.equal(doorOpeningSide(door,[0,0,1]),2);
  door.animationState = 2;
  assert.deepEqual(doorUsePoints(door),[[0,0,1],[0,0,-1]]);
});

test('planner detours around blockers and rejects disconnected or stacked floors', () => {
  const mesh = [];
  for (let x=-3;x<3;x++) for(let z=-3;z<3;z++) mesh.push(...floor(x,x+1,z,z+1));
  const navigator = new WalkmeshNavigator(mesh), obstacles = wall(0,-1.5,1.5);
  const start = [-2,0,0], route = navigator.path(start,[2,0,0],obstacles);
  assert.ok(route?.length > 1);
  let previous = start;
  for(const point of route) { assert.equal(navigator.segment(previous,point,obstacles),true); previous = point; }
  assert.deepEqual(route.at(-1),[2,0,0]);
  const disconnected = new WalkmeshNavigator([...floor(-3,-0.01,-3,3),...floor(0.01,3,-3,3)]);
  assert.equal(disconnected.path(start,[2,0,0]),null);
  const stacked = new WalkmeshNavigator([...mesh,...floor(-3,3,-3,3,4)]);
  assert.equal(stacked.path(start,[2,4,0]),null);
});

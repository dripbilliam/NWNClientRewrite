import assert from 'node:assert/strict';
import test from 'node:test';
import { buildRadialActions, buildGroundRadialActions, radialHit, radialActionRequest } from '../src/radial_actions.js';
const actor = { id:'player',kind:'player',areaId:'a' };
const target = (kind,extra = {}) => ({ id:'target',kind,areaId:'a',...extra });

test('radial sectors match native hooks and scale-normalized selection bands', () => {
  for (const [slot,x,y] of [[0,0,-100],[1,70,-70],[2,100,0],[3,70,70],[4,0,100],[5,-70,70],[6,-100,0],[7,-70,-70]]) {
    assert.equal(radialHit(x,y).octant,slot); assert.equal(radialHit(x,y).zone,'select');
    assert.equal(radialHit(x*2,y*2,2).octant,slot); assert.equal(radialHit(x*2,y*2,2).zone,'select');
  }
  assert.equal(radialHit(20,0).zone,'center'); assert.equal(radialHit(21,0).zone,'cancel');
  assert.equal(radialHit(56,0).zone,'cancel'); assert.equal(radialHit(57,0).zone,'select');
  assert.equal(radialHit(150,0).zone,'select'); assert.equal(radialHit(151,0).zone,'submenu');
  assert.equal(radialHit(300,0).zone,'submenu'); assert.equal(radialHit(301,0).zone,'exit');
  assert.throws(() => radialHit(0,0,0),/scale/);
});

test('door radial closes linked doors without choosing default traversal', () => {
  for(const state of [0,1,2]) {
    const menu = buildRadialActions(target('door',{animationState:state,linkedTo:'exit',lockable:true}),actor);
    const use = menu.entries.find(entry => entry.slot === 2);
    assert.equal(use.label,state ? 'Close' : 'Open'); assert.equal(use.action,'door.toggle');
    assert.equal(use.disabled,false);
    for(const slot of [1,3,5,6]) assert.equal(Boolean(menu.entries.find(entry=>entry.slot===slot).disabled),Boolean(state));
  }
  const destroyed = buildRadialActions(target('door',{animationState:3}),actor);
  assert.ok(destroyed.entries.filter(entry=>entry.slot!==0).every(entry=>entry.disabled));
  const noLock = buildRadialActions(target('door',{animationState:0,lockable:false,trapped:false}),actor);
  assert.ok(!noLock.entries.some(entry=>entry.slot===6));
  assert.equal(noLock.entries.find(entry=>entry.slot===3).disabled,true);
});

test('all object menu families expose commands or explicit placeholder systems', () => {
  for(const object of [target('door',{animationState:0}),target('creature'),actor,target('placeable'),target('item',{stackSize:2}),target('creature',{masterId:actor.id,associateType:4})]) {
    const menu = buildRadialActions(object,actor);
    assert.equal(new Set(menu.entries.map(entry=>entry.slot)).size,menu.entries.length);
    for(const entry of menu.entries) {
      assert.ok(entry.slot>=0 && entry.slot<8);
      assert.ok(entry.children || entry.action);
      if (entry.action && entry.action!=='door.toggle') assert.ok(entry.system);
      if (entry.children) assert.ok(entry.children().entries.length);
    }
  }
  assert.equal(buildRadialActions(target('creature'),actor).entries.length,8);
  assert.equal(buildRadialActions(actor,actor).entries.length,7);
});

test('lazy spell choices paginate without claiming unimplemented actor spells', () => {
  const missing = buildRadialActions(actor,actor).entries.find(entry=>entry.slot===1).children();
  assert.equal(missing.entries.length,1); assert.equal(missing.entries[0].action,'spell.select');
  const caster = {...actor,spells:Array.from({length:18},(_,index)=>({label:`Spell ${index}`,action:`spell.${index}`}))};
  let menu = buildRadialActions(caster,caster).entries.find(entry=>entry.slot===1).children();
  const labels=[];
  while(menu) { labels.push(...menu.entries.filter(entry=>entry.action).map(entry=>entry.label));menu=menu.entries.find(entry=>entry.children)?.children(); }
  assert.equal(labels.length,18); assert.equal(new Set(labels).size,18);
});

test('placeholder payload identifies target, actor, area and missing subsystem', () => {
  const object = target('creature'), entry = buildRadialActions(object,actor).entries.find(entry=>entry.slot===7);
  assert.deepEqual(radialActionRequest(entry,object,actor,[1,2,3]),{action:'conversation.start',targetId:'target',actorId:'player',areaId:'a',label:'Talk',system:'conversations',groundPoint:[1,2,3]});
});

test('ground menu preserves native slots and identifies unfinished position actions', () => {
  const menu = buildGroundRadialActions(actor);
  assert.equal(menu.title,'Ground');
  assert.deepEqual(menu.entries.map(entry=>entry.slot),[1,2,3,6]);
  const movement = menu.entries.find(entry=>entry.slot===2);
  assert.equal(movement.action,'movement.moveTo');
  assert.equal(radialActionRequest(movement,actor,actor,[4,0,8]).system,'ground movement requests');
  assert.ok(menu.entries.find(entry=>entry.slot===3).children().entries[0].system);
});

test('emotes preserve three native pages and associate commands retain their compass slots', () => {
  const self = buildRadialActions(actor,actor);
  const root = self.entries.find(entry=>entry.slot===7).children();
  assert.equal(root.entries.find(entry=>entry.slot===5).label,'Cheer');
  const second = root.entries.find(entry=>entry.slot===7).children();
  const third = second.entries.find(entry=>entry.slot===7).children();
  const leaves = [...root.entries,...second.entries,...third.entries].filter(entry=>entry.action);
  assert.equal(leaves.length,21); assert.ok(leaves.every(entry=>entry.system==='emote animation selection'));
  const commands = self.entries.find(entry=>entry.slot===5).children();
  assert.equal(commands.entries.find(entry=>entry.slot===2).label,'Attack nearest');
  assert.equal(commands.entries.find(entry=>entry.slot===6).label,'Heal me');
});

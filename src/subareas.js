import { NativeIdList } from './native_id_list.js';
import { intersectAreaSegments } from './area_collision.js';
import {OBJECT_INVALID} from './game_object_array.js';

const required = (p, name) => {
  if (typeof p[name] !== 'function') throw new Error(`Native subarea provider ${name} is unavailable`);
  return p[name];
};
const list = value => {
  if (!(value instanceof NativeIdList)) throw new Error('Native subarea ID list is unavailable');
  return value;
};
const ids = value => list(value).view();
const includes = (value, id) => list(value).indexOf(id) >= 0;
const result = value => { if (!Number.isInteger(value)) throw new Error('Native subarea integer result is unavailable'); return value; };

// Trigger140501b50 and encounter14043c350 use the same area segment
// intersection against ordered polygon edges. Z is ignored; no area returns0.
export function intersectSubareaPolygon(object, from, to, hasArea) {
  if (!hasArea) return 0;
  if (!Array.isArray(object.geometry)) throw new Error('Native subarea polygon is unavailable');
  const start = [Math.fround(from[0]), Math.fround(-from[2])], end = [Math.fround(to[0]), Math.fround(-to[2])];
  for (let index = 0; index < object.geometry.length; index++)
    if (intersectAreaSegments(start, end, object.geometry[index], object.geometry[(index + 1) % object.geometry.length])) return 1;
  return 0;
}

// InSubAreas14036c990 and IntersectingLineSegment14036ea30. Membership
// lists retain duplicate suppression/order. The >16 native search temporarily
// replaces/restores its tail as a sentinel; no callback occurs during that
// search, so indexOf has the same observable ordering/results.
export async function inSubareas(area, point, output, p) {
  let found = 0;
  for (let index = 0; index < ids(area.nativeSubareas).length; index++) {
    const id = ids(area.nativeSubareas)[index];
    if (includes(output, id)) continue;
    const object = await required(p, 'object')(id);
    if (!object) continue;
    const name = object.objectType === 7 ? 'inTrigger' : object.objectType === 11 ? 'inAOE' : object.objectType === 13 ? 'inEncounter' : null;
    if (name && result(await required(p, name)(object, point)) !== 0) { output.append(id); found = 1; }
  }
  return found;
}
export async function intersectSubareas(area, from, to, output, p) {
  let found = 0;
  for (let index = 0; index < ids(area.nativeSubareas).length; index++) {
    const id = ids(area.nativeSubareas)[index], object = await required(p, 'object')(id);
    if (!object || includes(output, id)) continue;
    const name = object.objectType === 7 ? 'lineTrigger' : object.objectType === 11 ? 'lineAOE' : object.objectType === 13 ? 'lineEncounter' : null;
    if (name && result(await required(p, name)(object, from, to)) !== 0) { output.append(id); found = 1; }
  }
  return found;
}

// HandleSubAreaStateChanges1403d5890..1403d608c. Exits before entries,
// crossed-but-outside emits enter then exit; crossed-and-inside both old/new
// emits exit then enter. Entry transition-event selection is a distinct owner.
export async function handleSubareaChanges(actor, next, crossed, transitionFlag, p) {
  list(next); const old = list(actor.nativeSubareaMembership);
  if (result(await required(p, 'dm')(actor)) !== 0) return 0;
  let changed = 0;
  const emit = async (object, code) => required(p, 'event')(code, actor.id, object.id, { scriptEvent: code, objectIds: [actor.id] });
  const entry = async object => transitionFlag === 0 || object.objectType !== 7 ? 12 : result(await required(p, 'entryEvent')(object));
  for (let index = 0; index < old.count; index++) {
    const id = old.ids[index];
    if (!includes(next, id)) {
      const object = await required(p, 'object')(id);
      if (object) { await emit(object, 13); changed = 1; }
    }
  }
  for (let index = 0; index < next.count; index++) {
    const id = next.ids[index];
    if (!includes(old, id)) {
      const object = await required(p, 'object')(id);
      if (object) await emit(object, await entry(object));
      changed = 1; // Native sets this even if target lookup fails.
    }
  }
  if (crossed) for (let index = 0; index < list(crossed).count; index++) {
    const id = crossed.ids[index], wasInside = includes(old, id), isInside = includes(next, id);
    if (wasInside !== isInside) continue;
    const object = await required(p, 'object')(id);
    if (object) {
      if (wasInside) { await emit(object, 13); await emit(object, await entry(object)); }
      else { await emit(object, await entry(object)); await emit(object, 13); }
    }
    // The native crossed-only branch never sets its changed return flag.
  }
  return changed;
}

// UpdateSubareasOnMoveTo1403db700..1403dba49: endpoint membership,
// following AOEs, optional crossed list, state changes, then conditional copy.
// Never return the misleading decompiler's allocator/free value.
export async function updateSubareasOnMove(actor, from, to, useProvided, provided, transitionFlag, p) {
  if (![useProvided, transitionFlag].every(Number.isInteger)) throw new Error('Native subarea movement flags are unavailable');
  const next = new NativeIdList(), area = await required(p, 'area')(actor);
  if (!area) { await p.warning?.('Native UpdateSubareasOnMoveTo warning: pArea == NULL'); return 0; }
  const oldCount = list(actor.nativeSubareaMembership).count;
  const found = await inSubareas(area, to, next, p);
  for (let index = 0; index < list(actor.nativeFollowingAOEs).count; index++) {
    const id = actor.nativeFollowingAOEs.ids[index], aoe = await required(p, 'aoe')(id);
    if (aoe) { await required(p, 'moveAOE')(aoe, to); if (!includes(next, id)) next.append(id); }
  }
  let crossed = provided;
  if (useProvided === 0) { crossed = new NativeIdList(); await intersectSubareas(area, from, to, crossed, p); }
  if (oldCount > 0 || found !== 0) {
    if (await handleSubareaChanges(actor, next, crossed, transitionFlag, p) === 1) {
      actor.nativeSubareaMembership.copyFrom(next); return 1;
    }
  }
  return 0;
}

// UpdateSubareasOnJumpPosition1403db4a0..1403db6fc. Unlike walking, only
// endpoint membership is tested. Capture the old count before AoE callbacks;
// following AoEs can mutate the actor's membership during their own jump.
// Assembly returns1 after a membership copy, independently of allocator/free.
export async function updateSubareasOnJump(actor,point,areaId,p){
  const area=areaId===OBJECT_INVALID?null:await required(p,'areaById')(areaId),next=new NativeIdList(),
    oldCount=list(actor.nativeSubareaMembership).count,found=area?await(p.inSubareas??inSubareas)(area,point,next,p):0;
  for(let i=0;i<list(actor.nativeFollowingAOEs).count;i++){
    const id=actor.nativeFollowingAOEs.ids[i],aoe=await required(p,'aoe')(id);
    if(aoe){await required(p,'jumpAOE')(aoe,area,point);if(!includes(next,id))next.append(id);}
  }
  if((oldCount>0||found!==0)&&await(p.handleChanges??handleSubareaChanges)(actor,next,null,0,p)===1){actor.nativeSubareaMembership.copyFrom(next);return 1;}
  return 0;
}

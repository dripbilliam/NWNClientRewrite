import { OBJECT_INVALID } from './game_object_array.js';

// CNWSObject +100 owns a linked list of separately allocated action records.
// Preserve record identity when a running action is removed and reinserted.
export class ObjectActionList {
  constructor() { this.head = null; this.tail = null; this.count = 0; }
  insert(action, front = false) {
    const link = { action, previous: front ? null : this.tail, next: front ? this.head : null };
    if (link.previous) link.previous.next = link; else this.head = link;
    if (link.next) link.next.previous = link; else this.tail = link;
    this.count++; return link;
  }
  remove(link) {
    if (link.previous) link.previous.next = link.next; else this.head = link.next;
    if (link.next) link.next.previous = link.previous; else this.tail = link.previous;
    this.count--; link.previous = link.next = null; return link.action;
  }
  insertBefore(action,next){
    if(!next)return this.insert(action);
    const link={action,previous:next.previous,next};
    if(link.previous)link.previous.next=link;else this.head=link;
    next.previous=link;this.count++;return link;
  }
  shift() { return this.head ? this.remove(this.head) : null; }
  *[Symbol.iterator]() { for (let link = this.head; link; link = link.next) yield link.action; }
}

export function createObjectActionState() {
  return { list: new ObjectActionList(), nextGroup: 0, lastGroup: 0,
    executingId: 65535, executingTargetId: OBJECT_INVALID, executingNode: null,
    startDay: 0, startTime: 0, lastRunDay: 0, lastRunTime: 0, running: false };
}

// SetGroupInterruptable14049aff0 changes every matching physical node.
export function setGroupInterruptable(state,group,value){
  for(const node of state.list)if(node.groupId===(group&65535))node.nativeField9c=value|0;
}

// Constructor 0x14048bcf0; AddAction/ToFront 0x14048cb80/14048d3f0.
// The zeroed 12 type/data slots correspond to +4 and +38; this is a local
// representation, not a serialized native pointer layout or network packet.
export function createObjectAction(actionId, groupId) {
  return { actionId: actionId >>> 0, groupId: groupId & 65535, nativeField9c: 1,
    parameterCount: 0, parameterTypes: new Uint32Array(12), parameterData: Array(12).fill(0) };
}

// AddActionNodeParameter 0x14048d2c0: types 1/2/3 sign-extend a raw i32,
// type 6 zero-extends a byte; type 4 copies a CExoString; type 5 owns a
// script situation. Keep float bits in their raw slot until a typed read.
export function setActionParameter(node, index, type, value) {
  index >>>= 0; type >>>= 0;
  node.parameterCount = (index + 1) & 65535;
  if (index >= 12) return;
  node.parameterTypes[index] = type;
  if ([1, 2, 3].includes(type)) node.parameterData[index] = value | 0;
  else if (type === 6) node.parameterData[index] = value & 255;
  else if (type === 4) {
    if (!(value instanceof Uint8Array)) throw new Error('Native action string bytes are unavailable');
    node.parameterData[index] = value.slice();
  } else if (type === 5) node.parameterData[index] = value;
}
export function actionParameter(node, index) {
  const type = node.parameterTypes[index], value = node.parameterData[index];
  if (type === 2) {
    const raw = new DataView(new ArrayBuffer(4)); raw.setInt32(0, value, true); return raw.getFloat32(0, true);
  }
  return type === 3 ? value >>> 0 : value;
}

export function addObjectAction(state, actionId, groupId = 65535, parameters = [], front = false) {
  if (!Number.isInteger(actionId) || !Number.isInteger(groupId)) throw new Error('Native action ID/group is unavailable');
  groupId &= 65535;
  if (groupId === 65535) {
    groupId = state.nextGroup & 65535;
    state.nextGroup = (groupId + 1) & 65535;
    if (state.nextGroup === 65535) state.nextGroup = 0;
    state.lastGroup = groupId;
  } else if (groupId === 65534) groupId = state.lastGroup;
  const node = createObjectAction(actionId, groupId);
  for (let index = 0; index < Math.min(12, parameters.length); index++) {
    const parameter = parameters[index];
    if (!parameter || (parameter.type >>> 0) === 0) break;
    setActionParameter(node, index, parameter.type, parameter.value);
  }
  state.list.insert(node, front); return node;
}

// AddActionAfterFront14048ced0: after the FIRST CONTIGUOUS GROUP,
// not merely the first record. Allocation/group/parameters match AddAction.
export function addObjectActionAfterFront(state,actionId,groupId=65535,parameters=[]){
  const first=state.list.head;const node=addObjectAction(state,actionId,groupId,parameters);
  if(!first)return node;
  const allocated=state.list.tail;let next=first;
  while(next&&next!==allocated&&next.action.groupId===first.action.groupId)next=next.next;
  if(next&&next!==allocated){state.list.remove(allocated);state.list.insertBefore(node,next);}
  return node;
}

// GetAcceptableAction 1404aba90..1404ababd, verified switch map. This is
// the group's summary filter, not validation for executing an engine action.
const acceptableActions = new Set([1,7,9,12,15,20,21,24,25,26,27,28,29,30,38,39,40,41,42,43,45,46,50,54,55,56,57,59]);
export function getAcceptableAction(actionId) { return Number(acceptableActions.has(actionId >>> 0)); }

// GetActionByGroupId 140494dd0: scan the FIRST contiguous matching group,
// keeping its LAST acceptable action. A repeated group later is ignored.
export function actionByGroupId(state, groupId) {
  groupId &= 65535;
  let found = false, result = null;
  for (const node of state.list) {
    if ((node.groupId & 65535) === groupId) {
      found = true; if (getAcceptableAction(node.actionId) === 1) result = node;
    } else if (found) break;
  }
  return result;
}

// GetSpellOrHealActionQueued 1403930e0, with group-index semantics from
// 140495c70 / 140495e90. Only queued actions count, never the executing node.
export function spellOrHealActionQueued(actor) {
  const state = actor.objectActionState;
  if (!state?.list) throw new Error('Native object action group list is unavailable');
  let previous = -1;
  for (const node of state.list) {
    const group = node.groupId & 65535;
    if (group === previous) continue;
    previous = group;
    const action = actionByGroupId(state, group);
    if (action && (action.actionId >>> 0) <= 56 &&
        (0x100400000008000n >> BigInt(action.actionId >>> 0) & 1n) !== 0n) return 1;
  }
  return 0;
}

// ComputeAIStateOnAction 0x140387e70. These are native AI summary values,
// distinct from MDL animation/creature status and script GetCurrentAction.
const priorityStates = new Map([[8, 12], [11, 13], [7, 10], [9, 11], [15, 14], [46, 14],
  [20, 15], [21, 16], [25, 17], [26, 18], [27, 19], [28, 20], [29, 21], [34, 22],
  [35, 23], [38, 24], [39, 25], [40, 26], [41, 27], [42, 28], [54, 29], [56, 30], [57, 31], [59, 32]]);
export function computeAIStateOnAction(actor, actionId, targetId = OBJECT_INVALID) {
  actionId |= 0;
  const current = actor.creatureAnimation & 255, priority = priorityStates.get(actionId);
  if (priority !== undefined) {
    if (current < 10) { actor.creatureAnimation = priority; actor.currentAITargetId = OBJECT_INVALID; }
  } else if (actionId === 12 && current < 2) {
    actor.creatureAnimation = 2; actor.currentAITargetId = targetId >>> 0;
  } else if ((actionId === 1 || actionId === 51) && current === 0) {
    actor.creatureAnimation = 1; actor.currentAITargetId = OBJECT_INVALID;
  } else if (actionId === 50 && current < 2) {
    actor.creatureAnimation = 2; actor.currentAITargetId = OBJECT_INVALID;
  }
}
// ComputeAIState 0x140387dc0 walks the QUEUED list first, then the executing
// action (+90/+94). The first priority action wins even over the current one.
export function computeAIState(actor) {
  const state = actor.objectActionState;
  if (!state) throw new Error('Native object action state is unavailable');
  actor.creatureAnimation = 0; actor.currentAITargetId = OBJECT_INVALID;
  for (const node of state.list) computeAIStateOnAction(actor, node.actionId,
    node.actionId === 12 ? node.parameterData[0] >>> 0 : OBJECT_INVALID);
  if ((state.executingId & 65535) !== 65535)
    computeAIStateOnAction(actor, state.executingId & 65535, state.executingTargetId);
}

export async function disposeObjectAction(node, deleteSituation) {
  if (!Number.isInteger(node.parameterCount) || node.parameterCount < 0 || node.parameterCount > 12)
    throw new Error('Malformed native action parameter count is unsupported');
  for (let index = 0; index < node.parameterCount; index++) {
    const type = node.parameterTypes[index], value = node.parameterData[index];
    if (type === 5 && value) {
      if (typeof deleteSituation !== 'function') throw new Error('Native script situation disposal is unavailable');
      await deleteSituation(value);
    }
    if (type === 4 || type === 5) node.parameterData[index] = 0;
  }
}
function disposalPreflight(node, deleteSituation) {
  if (!Number.isInteger(node.parameterCount) || node.parameterCount < 0 || node.parameterCount > 12)
    throw new Error('Malformed native action parameter count is unsupported');
  if (typeof deleteSituation !== 'function' && node.parameterData.some((value, index) =>
    index < node.parameterCount && node.parameterTypes[index] === 5 && value))
    throw new Error('Native script situation disposal is unavailable');
}
// DeleteCurrentAIAction140491570. Calls ClearAction(head,1), and removes
// only exact-one success; it has no commandability gate or path-reset tail.
export async function deleteCurrentObjectAction(actor,{clearAction,deleteSituation}={}){
 const list=actor.objectActionState?.list;if(!list||typeof clearAction!=='function')throw new Error('Native current-action deletion providers are unavailable');
 const node=list.head?.action;if(!node)return;disposalPreflight(node,deleteSituation);
 if(await clearAction(actor,node,1)===1){const removed=list.shift();if(removed)await disposeObjectAction(removed,deleteSituation);}
}
// RemoveGroup140498860. Visits every matching group, including separated
// repeats, and recomputes head identity for each ClearAction call. It does
// not require commandability or invoke the ClearAllActions path-reset tail.
export async function removeObjectActionGroup(actor,groupId,{clearAction,deleteSituation}={}){
  if(!Number.isInteger(groupId)||typeof clearAction!=='function')throw new Error('Native group-removal providers are unavailable');
  groupId&=65535;const list=actor.objectActionState?.list;
  if(!list)throw new Error('Native action group list is unavailable');
  for(let link=list.head;link;){const next=link.next,node=link.action;
    if((node.groupId&65535)===groupId){
      disposalPreflight(node,deleteSituation);
      if(await clearAction(actor,node,node===list.head?.action)===1){list.remove(link);await disposeObjectAction(node,deleteSituation);}
    }
    link=next;
  }
}

// ClearAllActions 0x140490b80 calls virtual ClearAction for each node and
// removes only exact-one successes, with head identity checked each time.
export async function clearObjectActions(actor, { clearAction, resetPath, deleteSituation } = {}) {
  if (Number(actor.commandable) !== 1) return;
  if (typeof clearAction !== 'function' || actor.objectType === 5 && typeof resetPath !== 'function')
    throw new Error('Native action cancellation providers are unavailable');
  const list = actor.objectActionState.list;
  for (let link = list.head; link;) {
    const next = link.next, node = link.action;
    disposalPreflight(node, deleteSituation);
    if (await clearAction(actor, node, node === list.head?.action) === 1) {
      list.remove(link); await disposeObjectAction(node, deleteSituation);
    }
    link = next;
  }
  if (actor.objectType === 5) await resetPath(actor);
}

// ActionManager 0x14037cbc0 applies only when a client object exists, which
// is NOT equivalent to the creature's PC flag or familiar possession.
export async function manageObjectActions(actor, request, { hasClient, clearActions } = {}) {
  if (typeof hasClient !== 'function' || typeof clearActions !== 'function') throw new Error('Native action manager providers are unavailable');
  if (!await hasClient(actor)) return;
  computeAIState(actor); request >>>= 0;
  if (((request - 1) >>> 0) < 2 && (actor.creatureAnimation & 255) < 10) await clearActions(actor);
  if ((((request - 4) >>> 0) & 0xfffffffb) === 0) await clearActions(actor);
}

// RunActions 0x1404ac010 lifecycle. Dispatch supplies the native per-action
// implementation and type gate. Return 1 retains the record at the head;
// 2/3 dispose it. Stop actions 1,5,48,51 and the strict microsecond budget
// boundary preserve native frame cadence. Overflow policy is a separate hook.
export async function runObjectActions(actor, day, time, startedAt, providers = {}) {
  const state = actor.objectActionState;
  if (!state) throw new Error('Native object action state is unavailable');
  if (state.running) throw new Error('Reentrant native object action dispatch');
  for (const name of ['dispatch', 'microseconds', 'completed', 'lastAction', 'overflow'])
    if (typeof providers[name] !== 'function') throw new Error(`Native action lifecycle provider ${name} is unavailable`);
  day >>>= 0; time >>>= 0; startedAt = BigInt.asUintN(64, BigInt(startedAt));
  state.running = true;
  try {
    while (state.list.head) {
      // Preflight preserves unavailable work before native removal/side effects.
      if (providers.preflight) await providers.preflight(actor, state.list.head.action);
      disposalPreflight(state.list.head.action, providers.deleteSituation);
      const node = state.list.shift(), attack = node.actionId === 12;
      if (state.startDay === 0 && state.startTime === 0) { state.startDay = day; state.startTime = time; }
      state.executingNode = node; state.executingId = node.actionId & 65535;
      if (attack) state.executingTargetId = node.parameterData[0] >>> 0;
      let result;
      try {
        result = await providers.dispatch(actor, node);
        if (!Number.isInteger(result)) throw new Error('Native action result is unavailable');
      } catch (error) {
        // An unavailable implementation cannot masquerade as native completion.
        state.list.insert(node, true); throw error;
      } finally {
        if (attack) state.executingTargetId = OBJECT_INVALID;
        state.executingNode = null;
        try { await providers.lastAction(actor, state.executingId); }
        finally { state.executingId = 65535; state.lastRunDay = day; state.lastRunTime = time; }
      }
      if (attack && result !== 1) { actor.attackActionTargetId = OBJECT_INVALID; actor.nativeAttackTarget724 = OBJECT_INVALID; }
      if (result === 1) state.list.insert(node, true);
      else {
        await providers.completed(actor, node);
        await disposeObjectAction(node, providers.deleteSituation);
        state.startDay = state.startTime = 0;
      }
      if (result === 1 || BigInt.asUintN(64, BigInt(await providers.microseconds()) - startedAt) > 1000n ||
          node.actionId < 52 && (0x9000000000022n >> BigInt(node.actionId) & 1n)) break;
    }
    await providers.overflow(actor);
  } finally { state.running = false; }
}

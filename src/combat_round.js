import { attacksPerRound, weaponRule } from './combat_weapon.js';
import { creatureSize } from './combat_context.js';
import { rulesetInt } from './combat_stats.js';
import { OBJECT_INVALID } from './game_object_array.js';
import { createRoundAction, addRoundAction } from './combat_action.js';
import { createAttackData, clearAllAttacks,getAttackData } from './combat_attack_data.js';

const f32 = Math.fround;
const scaled = (time, length, decrease) => length <= 0 ? 0 : Math.trunc(f32(f32(time / length) * f32(length - decrease)));

export function createCombatRound(rules = {}) {
  return { started: false, spellCastRound: false, timer: 0, length: 0, overlap: 0, bleed: 0, paused: false,
    pausedBy: OBJECT_INVALID, pauseTimer: 0, infinitePause: false, currentAttack: 0, attackGroup: 255,
    deflectArrow: false, weaponSucks: false, epicDodgeUsed: false, parryIndex: 0, attacksOfOpportunity: rulesetInt(rules, 'NUM_ATTACKS_OF_OPPORTUNITY', 1),
    cleaveAttacks: rulesetInt(rules, 'NUM_CLEAVE_ATTACKS', 1), circleKickAttacks: rulesetInt(rules, 'NUM_CIRCLE_KICK_ATTACKS', 1), newAttackTargetId: OBJECT_INVALID, onhandAttacks: 0, offhandAttacks: 0,
    offhandTaken: 0, extraTaken: 0, additionalAttacks: 0, bonusEffectAttacks: 0, parryActions: 0,
    dodgeTargetId: OBJECT_INVALID, actions: [], specialAttacks: [], specialAttackParameters: [], specialAttackSequence: 0, attacks: Array.from({ length: 50 }, createAttackData) };
}

// InsertSpecialAttack 140377860. The second ushort queue contains a
// sequence, not the insertion index. FFFE wraps to 1; FFFF wraps to 0.
export function insertSpecialAttack(round, type, index) {
  if (![type,index,round.specialAttackSequence].every(Number.isInteger) ||
      !Array.isArray(round.specialAttacks) || !Array.isArray(round.specialAttackParameters))
    throw new Error('Native special attack insertion state is unavailable');
  if (round.specialAttacks.length && (index < 0 || index > round.specialAttacks.length || index > round.specialAttackParameters.length))
    throw new Error('Native out-of-bounds special attack insertion is unsupported');
  let sequence = round.specialAttackSequence & 65535;
  if (sequence === 65534) sequence = 0;
  round.specialAttackSequence = (sequence + 1) & 65535;
  if (round.specialAttacks.length) {
    round.specialAttacks.splice(index, 0, type & 65535);
    round.specialAttackParameters.splice(index, 0, sequence);
  } else {
    round.specialAttacks.push(type & 65535);
    round.specialAttackParameters.push(sequence);
  }
}

// AddSpecialAttack140374da0. Prefer an empty remaining physical attack when
// a round is running and the special queue is empty. Otherwise append at most
//50 queued records, preserving the shared WORD sequence rollover.
export function addSpecialAttack(round,type,warning){
  if(!Number.isInteger(type)||!Number.isInteger(round.specialAttackSequence)||!Array.isArray(round.specialAttacks)||!Array.isArray(round.specialAttackParameters))throw new Error('Native special attack append state is unavailable');
  const next=()=>{let sequence=round.specialAttackSequence&65535;if(sequence===65534)sequence=0;round.specialAttackSequence=(sequence+1)&65535;return sequence;};
  const count=()=>{const values=[round.onhandAttacks,round.offhandAttacks,round.additionalAttacks,round.bonusEffectAttacks];if(!values.every(Number.isInteger))throw new Error('Native special attack counts are unavailable');const total=values.reduce((n,v)=>(n+v)|0,0);return total>1?total&255:1;};
  if(Number(round.started)===1&&round.specialAttacks.length===0){
    for(let index=round.currentAttack&255;index<count();index++){
      if(getAttackData(round,index,warning).attackType!==0)continue;
      getAttackData(round,index,warning).attackType=type&65535;
      getAttackData(round,index,warning).specialParameter=next();return;
    }
  }
  if(round.specialAttacks.length>=50)return;
  round.specialAttacks.push(type&65535);round.specialAttackParameters.push(next());
}

// AddAttackOfOpportunity 140374320..140374488. A running round gets a
// time-zero strike BEFORE its former head. Its duration divisor always uses
// (count-3)*0.5+3, including counts 1/2. An idle round only stores the bonus
// count and special attack; its normal startup subsequently builds actions.
export function addAttackOfOpportunity(round, targetId) {
  if (!Number.isInteger(targetId)) throw new Error('Native opportunity target ID is unavailable');
  if (Number(round.started) !== 0) {
    const total = (round.onhandAttacks + round.offhandAttacks + round.additionalAttacks + round.bonusEffectAttacks) | 0;
    const count = total > 1 ? total & 255 : 1;
    const cost = Math.min(count * 750 + 500, 3000);
    const duration = Math.trunc(f32(f32(cost) / f32(f32((count - 3) * 0.5) + 3)));
    decrementRoundLength(round, duration, true);
    round.actions.unshift(createRoundAction(1, targetId >>> 0,
      { type: 'attack', time: 0, animation: 9, duration, count: 1, followTarget: 0 }));
  }
  round.additionalAttacks = (round.additionalAttacks + 1) | 0;
  insertSpecialAttack(round, 65002, 0);
}

// AddParryAttack 140374b20. Capture the original head time BEFORE rescaling
// it. No additional-attack counter is incremented, unlike opportunity attacks.
export function addParryAttack(round,targetId){
  if(!Number.isInteger(targetId))throw new Error('Native Parry target ID is unavailable');
  const time=round.actions.length?(round.actions[0].time-1)|0:0;
  const total=(round.onhandAttacks+round.offhandAttacks+round.additionalAttacks+round.bonusEffectAttacks)|0;
  const count=total>1?total&255:1,cost=Math.min(count*750+500,3000);
  const duration=Math.trunc(f32(f32(cost)/f32(f32((count-3)*0.5)+3)));
  decrementRoundLength(round,duration,true);
  round.actions.unshift(createRoundAction(1,targetId>>>0,{type:'attack',time,animation:9,duration,count:1,followTarget:0}));
  insertSpecialAttack(round,65003,0);
}
// AddParryIndex 140374ca0: enqueue a type8 skip at time zero. This does not
// directly increment parryIndex or currentAttack; consuming AI performs that.
export function addParryIndex(round){
  if(Number(round.started)!==0)addRoundAction(round,createRoundAction(8));
}

// AddCircleKickAttack1403744a0 / AddCleaveAttack140374600. Both insert
// BEFORE the captured head (not through the sorted AddAction owner), even
// for an idle round. Constructor +18 remains1: unlike AoO/Parry these actions
// follow the current target. Counts are signed dwords, then truncated to BYTE.
function addFollowupAttack(round, targetId, feat) {
  if (!Number.isInteger(targetId) || targetId < 0 || targetId > 0xffffffff) throw new Error('Native follow-up target ID is unavailable');
  const counts = [round.onhandAttacks, round.offhandAttacks, round.additionalAttacks, round.bonusEffectAttacks];
  if (!counts.every(Number.isInteger) || !Array.isArray(round.actions)) throw new Error('Native follow-up round storage is unavailable');
  const total = counts.reduce((sum, value) => (sum + value) | 0, 0), count = total > 1 ? total & 255 : 1;
  const cost = Math.min(count * 750 + 500, 3000);
  const duration = Math.trunc(f32(f32(cost) / f32(f32((count - 3) * 0.5) + 3)));
  decrementRoundLength(round, duration, true);
  round.actions.unshift(createRoundAction(1, targetId >>> 0, { type: 'attack', time: 0, animation: 9, duration, count: 1 }));
  round.additionalAttacks = (round.additionalAttacks + 1) | 0;
  insertSpecialAttack(round, feat, 0);
}
export function addCircleKickAttack(round, targetId) { addFollowupAttack(round, targetId, 409); }
export function addCleaveAttack(round, targetId, great) {
  if (!Number.isInteger(great)) throw new Error('Native Great Cleave flag is unavailable');
  addFollowupAttack(round, targetId, great === 1 ? 391 : 6);
}

// InitializeNumberOfAttacks 0x1403773a0. Mutates combat mode when Flurry or
// Rapid Shot are no longer legal for the current equipment.
function* numberOfAttacksSteps(round, actor, items, rules) {
  const right = items.find(i => i.slot === 16), left = items.find(i => i.slot === 32), size = creatureSize(actor, rules);
  const has = feat => actor.stats.feats.includes(feat), rule = (name, fallback) => rulesetInt(rules, name, fallback);
  const count = attacksPerRound(actor, items, rules), crossbow = [6, 7].includes(right?.data.BaseItem);
  round.onhandAttacks = crossbow ? rule('CROSSBOW_ATTACKS', 1) : actor.slowed ? rule('SLOWED_ATTACKS', 1) : actor.overrideAttacksPerRound || count;
  if (crossbow && count > round.onhandAttacks && has(411)) round.onhandAttacks = count;
  round.offhandAttacks = 0;
  if (right && !weaponRule(right, rules, 'RangedWeapon')) {
    const relative = (weaponRule(right, rules, 'WeaponSize') & 255) - size;
    if (relative < 1 ? left && weaponRule(left, rules, 'WeaponType') && weaponRule(left, rules, 'WeaponWield') !== 7 : weaponRule(right, rules, 'WeaponWield') === 8) round.offhandAttacks = has(20) ? 2 : 1;
  }
  if (actor.combatMode === 10) { round.onhandAttacks = rule('DIRTY_FIGHTING_NUM_ATTACKS_PER_ROUND', 1); round.offhandAttacks = 0; }
  if (actor.combatMode === 5) {
    const difference = (weaponRule(right, rules, 'WeaponSize') & 255) - size;
    const relative = difference >= -2 && difference <= 1 ? difference : -10;
    if (right&&!weaponRule(right, rules, 'IsMonkWeapon')&&!has(899)&&!(relative<0&&has(866)))yield 0;
    // Native falls through this assignment even after disabling an invalid
    // mode. Preserve the current-round bonus rather than correcting the quirk.
    round.additionalAttacks = 1;
  } else if (actor.combatMode === 6) {
    if(!right||!(weaponRule(right,rules,'RangedWeapon')&255)||crossbow)yield 0;
    round.additionalAttacks = 1;
  }
  if (Number(actor.hasted)===1) round.additionalAttacks = (round.additionalAttacks + rule('HASTED_BONUS_ATTACKS', 1)) | 0;
  round.offhandTaken = 0; round.extraTaken = 0;
  return (round.onhandAttacks + round.offhandAttacks + round.additionalAttacks + round.bonusEffectAttacks) & 255;
}
export function initializeNumberOfAttacks(round,actor,items,rules){
  const steps=numberOfAttacksSteps(round,actor,items,rules);
  for(let result=steps.next();;result=steps.next()){
    if(result.done)return result.value;
    // Only mode5/6 reach this cleanup. Their activity bits have no effect
    // handlers; SetCombatMode(0,1) still obeys the locked-bit veto.
    const bit=actor.combatMode===5?0x4000:0x8000;
    if(!(actor.lockedActivities&bit))actor.activities=((actor.activities??0)&~bit)>>>0;
    actor.combatMode=0;
  }
}
export async function initializeNumberOfAttacksAsync(round,actor,items,rules,setMode){
  const steps=numberOfAttacksSteps(round,actor,items,rules);
  for(let result=steps.next();;result=steps.next()){
    if(result.done)return result.value;
    if(typeof setMode!=='function')throw new Error('Native attack-count combat-mode cleanup is unavailable');
    await setMode(actor,result.value,1);
  }
}

export function decrementRoundLength(round, amount, allowBleed = false) {
  if (!round.started) return;
  let length = round.length;
  if (length - amount < 0 && amount - length <= 1000 - round.overlap) {
    // Native assignment replaces length before computing the overlap update;
    // the resulting overlap remains unchanged (0x140375a6c..0x140375a8a).
    length = amount + 1;
  } else if (length - amount < 0 && allowBleed) length = amount;
  for (const action of round.actions) action.time = scaled(action.time, length, amount);
  round.timer = scaled(round.timer, length, amount);
  round.length = Math.max(length, amount) - amount;
}

// AddCombatStep 140374770..140374808: type4, duration500, followed by
// another decrement. The initial range-adjustment step uses type5 separately.
export function addCombatStep(round,time,targetId){
  addRoundAction(round,createRoundAction(4,targetId,{type:'combatStep',time:time|0,duration:500}));
  decrementRoundLength(round,500);
}

// AddReaction140374d10..140374d9f inserts type3 at timer+delay only
// when the round's started DWORD is nonzero. Ties preserve insertion order.
export function addReaction(round,delay,duration){
  if(Number(round.started)!==0)addRoundAction(round,createRoundAction(3,OBJECT_INVALID,
    {time:((round.timer|0)+(delay|0))|0,duration:duration|0}));
}

// InitializeAttackActions 0x140376ee0 uses three animation groups, rather
// than spacing all attacks evenly across six seconds. Timers are compressed
// here; the consuming AI must preserve its native animation pause lifecycle.
export function initializeAttackActions(round, actor, targetId, { initialCombatStep = false, broadcastState } = {}) {
  const total = (round.onhandAttacks + round.offhandAttacks + round.additionalAttacks + round.bonusEffectAttacks) | 0;
  const count = total > 1 ? total & 255 : 1;
  round.currentAttack = 0;
  if (actor.combatMode === 1) {
    if (typeof broadcastState !== 'function') throw new Error('Native Parry startup broadcast is unavailable');
    const result=broadcastState(actor);
    if(result?.then)throw new Error('Async Parry startup requires startCombatRoundAsync');
    round.parryActions = count; round.parryIndex = 0; return;
  }
  const speed = actor.combatAnimationSpeed & 255;
  const start = actor.hasted ? 250 - Math.trunc(f32(speed * 12.5)) : actor.slowed ? 1000 : 1000 - Math.trunc(f32(speed * 37.5));
  const groupCount = Math.min(count, 3), counts = Array.from({ length: groupCount }, (_, index) => Math.trunc(count / groupCount) + Number(index < count % groupCount));
  const cost = Math.min(count * 750 + 500, 3000), divisor = count < 3 ? count : f32(f32((count - 3) * 0.5) + 3);
  const duration = Math.trunc(f32(cost / divisor));
  if (initialCombatStep) round.actions.push(createRoundAction(5, targetId, { type: 'combatStep', time: 0, duration: 500 }));
  for (let index = 0; index < groupCount; index++) round.actions.push(createRoundAction(1, targetId, { type: 'attack', animation: 9, time: start + 2000 * index, duration, count: counts[index] }));
  if (count < 2) addCombatStep(round,3000,targetId);
  decrementRoundLength(round, cost);
}

function beginCombatRound(round) {
  round.started = true; round.spellCastRound = false; round.timer = 0;
  if (!round.overlap && !round.bleed) round.length = 6000;
  else if (round.overlap > 0) round.length = 6000 - round.overlap;
  else { const consumed = Math.min(1000, round.bleed); round.length = 6000 - consumed; round.bleed -= consumed; }
  round.paused = false; round.pausedBy = OBJECT_INVALID; round.pauseTimer = 0;
  round.actions.length = 0;
}
function finishCombatRoundStart(round, actor, targetId, random) {
  round.dodgeTargetId = targetId; round.deflectArrow = true; round.weaponSucks = false;
  if (!actor.isPC && !actor.isPossessedFamiliar) {
    const draw = random.next();
    if (!round.length) throw new Error('NPC combat step causes a native modulo-by-zero fault');
    addCombatStep(round,draw%round.length,targetId);
  }
  round.actions.sort((a, b) => a.time - b.time);
  return round;
}
export function startCombatRound(round, actor, targetId, items, rules, random, { initialCombatStep, broadcastState } = {}) {
  if (typeof initialCombatStep !== 'boolean') throw new Error('Initial melee combat-step range check is unavailable');
  if(actor.pendingCombatMode)throw new Error('Native pending combat mode requires its SetCombatMode lifecycle');
  if(actor.combatMode===1&&typeof broadcastState!=='function')throw new Error('Native Parry startup broadcast is unavailable');
  beginCombatRound(round);clearAllAttacks(round);
  initializeNumberOfAttacks(round, actor, items, rules);
  initializeAttackActions(round, actor, targetId, { initialCombatStep,broadcastState });
  return finishCombatRoundStart(round,actor,targetId,random);
}

// StartCombatRound 140379e80, including awaited native side effects in
// call order. The pure scheduler cannot substitute assignment for mode changes
// or move the Parry broadcast after the NPC random draw/orientation lock.
export async function startCombatRoundAsync(round,actor,targetId,items,rules,random,p={}){
  for(const name of ['initialCombatStep','broadcastState','setLock','setCombatMode'])
    if(typeof p[name]!=='function')throw new Error(`Native round startup provider ${name} is unavailable`);
  await p.preflight?.(actor,targetId);
  beginCombatRound(round);
  if(actor.pendingCombatMode){await p.setCombatMode(actor,actor.pendingCombatMode&255,1);actor.pendingCombatMode=0;}
  clearAllAttacks(round);await initializeNumberOfAttacksAsync(round,actor,items,rules,p.setCombatMode);
  if(actor.combatMode===1){
    round.currentAttack=0;await p.broadcastState(actor);
    const total=(round.onhandAttacks+round.offhandAttacks+round.additionalAttacks+round.bonusEffectAttacks)|0;
    round.parryActions=total>1?total&255:1;round.parryIndex=0;
  }else{
    const initialCombatStep=await p.initialCombatStep(actor,targetId);
    if(typeof initialCombatStep!=='boolean')throw new Error('Initial melee combat-step range check is unavailable');
    initializeAttackActions(round,actor,targetId,{initialCombatStep});
  }
  finishCombatRoundStart(round,actor,targetId,random);await p.setLock(actor,targetId);
  return round;
}

// InitializeAttackActions 1403770be..140377205: native 3D vector length
// and inclusive desired-range +/- 0.25 band (140d82160). This is not the approach/LOS test.
export async function initialAttackCombatStep(actor,targetId,p){
  const target=p.object(targetId);
  if(!target||target.objectType<=4||await p.dead(target)!==0||await p.dying(target)!==0)return false;
  if(!Number.isInteger(actor.perceptionUpdateFlags))throw new Error('Native round movement flags are unavailable');
  if(!(actor.perceptionUpdateFlags&2))return false;
  if(await p.ranged(actor)!==0)return false;
  const desired=Math.fround(await p.desiredRange(actor,targetId));
  if(![actor,target].every(o=>Array.isArray(o.position)&&o.position.length===3&&o.position.every(Number.isFinite)))
    throw new Error('Native round startup positions are unavailable');
  const dx=f32(f32(actor.position[0])-f32(target.position[0])),dy=f32(f32(-actor.position[2])-f32(-target.position[2])),dz=f32(f32(actor.position[1])-f32(target.position[1]));
  const squared=f32(f32(f32(dx*dx)+f32(dy*dy))+f32(dz*dz));
  const distance=squared>0?f32(Math.sqrt(squared)):0;
  return f32(desired-0.25)>distance||distance>f32(desired+0.25);
}

function beginRoundEnd(round) {
  round.pausedBy = OBJECT_INVALID; round.pauseTimer = 0; round.started = false; round.spellCastRound = false;
  round.timer = 0; round.length = 0; round.paused = false;
}
function finishRoundEnd(round, actor, rules) {
  clearAllAttacks(round); round.actions.length = 0; round.dodgeTargetId = OBJECT_INVALID; round.epicDodgeUsed = false;
  actor.attackTargetId = OBJECT_INVALID; round.additionalAttacks = 0;
  round.attacksOfOpportunity = rulesetInt(rules, 'NUM_ATTACKS_OF_OPPORTUNITY', 1);
  round.cleaveAttacks = rulesetInt(rules, 'NUM_CLEAVE_ATTACKS', 1);
  round.circleKickAttacks = rulesetInt(rules, 'NUM_CIRCLE_KICK_ATTACKS', 1);
  if (!actor.isPC && !actor.isPossessedFamiliar) actor.combatMode = 0;
}
function roundEndCallbacks(processPending, roundEnd, isDead) {
  if ([processPending, roundEnd, isDead].some(fn => typeof fn !== 'function')) throw new Error('Combat round end lifecycle callbacks are unavailable');
}
export function endCombatRound(round, actor, rules, { processPending, roundEnd, isDead } = {}) {
  roundEndCallbacks(processPending, roundEnd, isDead);
  beginRoundEnd(round);
  if (processPending()?.then) throw new Error('Async round end requires endCombatRoundAsync');
  finishRoundEnd(round, actor, rules);
  if (!isDead(actor) && roundEnd(actor)?.then) throw new Error('Async round end requires endCombatRoundAsync');
}
export async function endCombatRoundAsync(round, actor, rules, { processPending, roundEnd, isDead } = {}) {
  roundEndCallbacks(processPending, roundEnd, isDead);
  beginRoundEnd(round);
  await processPending();
  finishRoundEnd(round, actor, rules);
  if (!isDead(actor)) await roundEnd(actor);
}

export function weaponAttackType(round, items, random) {
  const inSlot = slot => items.find(i => i.slot === slot);
  const right = inSlot(16), left = inSlot(32), natural = !right && !left && [16384, 32768, 65536].some(inSlot);
  const index = (round.currentAttack & 255) + 1;
  const offhand = round.offhandAttacks !== 0 && index > round.bonusEffectAttacks + round.onhandAttacks + round.additionalAttacks;
  const extra = (round.additionalAttacks !== 0 || round.bonusEffectAttacks !== 0) && index > round.onhandAttacks;
  if (!natural) return offhand ? 2 : right ? extra ? 6 : 1 : extra ? 8 : 7;
  if (random.next() % 4 === 0) return inSlot(65536) ? 5 : inSlot(16384) ? 3 : inSlot(32768) ? 4 : 0;
  if (inSlot(16384) && inSlot(32768)) return random.next() % 2 ? 3 : 4;
  return inSlot(16384) ? 3 : inSlot(32768) ? 4 : inSlot(65536) ? 5 : 0;
}

// GetOffHandAttack 0x140376400..140376431 does not consume an attack.
export function offhandAttack(round) {
  return Number(round.offhandAttacks !== 0 && (round.currentAttack & 255) + 1 >
    ((round.bonusEffectAttacks + round.additionalAttacks + round.onhandAttacks) | 0));
}

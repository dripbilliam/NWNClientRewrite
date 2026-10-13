import { OBJECT_INVALID } from './game_object_array.js';
import { getAttackData, copyAttackData } from './combat_attack_data.js';
import { setRoundPaused, setPauseTimer } from './combat_timing.js';

export function attackResultDoesDamage(result) {
  result &= 255;
  return result < 11 && (0x4ea >>> result & 1) !== 0;
}
const requireProviders = (providers, names) => {
  for (const name of names) if (typeof providers[name] !== 'function') throw new Error(`Native strike provider ${name} is unavailable`);
};
const integer = (value, name) => {
  if (!Number.isInteger(value)) throw new Error(`Native strike ${name} is unavailable`);
  return value | 0;
};
export function setCurrentAttack(round, value, warning = () => {}) {
  round.currentAttack = value & 255;
  if (round.currentAttack > 49) warning("Native warning: Error! Attempting to set a really high current attack value... We're screwed!!");
}
function beginGroup(round, warning) {
  const index = round.currentAttack & 255, record = getAttackData(round, index, warning);
  round.attackGroup = ((round.attackGroup & 255) + 1) & 255; record.group = round.attackGroup;
  return { index, record, group: round.attackGroup };
}
// ResolveMeleeAttack 0x1403e64e0 (also inlined by ResolveAttack). Damage
// resolution fills records here; SignalMeleeDamage schedules HP application.
export async function resolveMeleeGroup(actor, target, count, duration, providers = {}) {
  if (!target) return;
  count = integer(count, 'melee count'); duration = integer(duration, 'animation duration');
  if (count < 0) throw new Error('Native negative melee group count is unsupported');
  requireProviders(providers, ['weaponAttackType', 'situational', 'cachedSpecial', 'attackRoll', 'damage', 'postDamage', 'animations', 'specialAttack', 'signal']);
  integer(actor.combatMode, 'combat mode');
  await providers.preflight?.(actor, target, count);
  const round = actor.combatRound;
  let { index, record, group } = beginGroup(round, providers.warning);
  for (let i = 0; i < count; i++) {
    record.group = group; record.targetId = target.id; record.combatMode = integer(actor.combatMode, 'combat mode');
    record.weaponAttackType = integer(await providers.weaponAttackType(actor), 'weapon attack type');
    await providers.situational(actor, target, record);
    if (record.coupDeGrace === 0) await providers.cachedSpecial(actor, record);
    if (record.attackType === 0) {
      await providers.attackRoll(actor, target, record);
      if (attackResultDoesDamage(record.result)) {
        await providers.damage(actor, target, record); await providers.postDamage(actor, target, record);
      }
      await providers.animations(actor, i, count, target, duration, record);
    } else await providers.specialAttack(actor, i, count, target, duration, record);
    index = (index + 1) >>> 0; setCurrentAttack(round, index, providers.warning);
    record = getAttackData(round, index, providers.warning);
  }
  await providers.signal(actor, target, count);
}
// ResolveRangedAttack 0x1403ea290 limits the group to available ammo, while
// passing available count to SignalRangedDamage. It does not write +57 mode.
export async function resolveRangedGroup(actor, target, count, duration, providers = {}) {
  count = integer(count, 'ranged count'); duration = integer(duration, 'animation duration');
  if (count < 0) throw new Error('Native negative ranged group count is unsupported');
  requireProviders(providers, ['setAnimation']);
  const resume = async () => { setRoundPaused(actor.combatRound, 0, OBJECT_INVALID); setPauseTimer(actor.combatRound, 0, 0); await providers.setAnimation(actor, 1); };
  if (!target) { await resume(); return; }
  requireProviders(providers, ['ammunition']);
  const available = integer(await providers.ammunition(actor, count), 'available ammunition');
  if (available === 0) { await resume(); return; }
  if (available < 0) throw new Error('Native negative available ammunition is unsupported');
  requireProviders(providers, ['weaponAttackType', 'situational', 'cachedSpecial', 'attackRoll', 'damage', 'postDamage', 'miss', 'animations', 'specialAttack', 'signal']);
  await providers.preflight?.(actor, target, count, available);
  const round = actor.combatRound;
  let { index, record, group } = beginGroup(round, providers.warning);
  for (let i = 0; i < count && i < available; i++) {
    record.group = group; record.targetId = target.id; record.ranged = 1;
    record.weaponAttackType = integer(await providers.weaponAttackType(actor), 'weapon attack type');
    await providers.situational(actor, target, record);
    if (record.coupDeGrace === 0) await providers.cachedSpecial(actor, record);
    if (record.attackType === 0) {
      await providers.attackRoll(actor, target, record);
      if (attackResultDoesDamage(record.result)) {
        await providers.damage(actor, target, record); await providers.postDamage(actor, target, record);
      } else await providers.miss(actor, target, record);
      await providers.animations(actor, target, duration, record);
    } else await providers.specialAttack(actor, target, duration, record);
    index = (index + 1) >>> 0; setCurrentAttack(round, index, providers.warning);
    record = getAttackData(round, index, providers.warning);
  }
  await providers.signal(actor, target, available);
}
// SignalMeleeDamage 0x1403ed7e0. Native AI event IDs, not wire messages.
// Scheduling consumes the original lists, but the attack event uses a copy.
export async function signalMeleeDamage(actor, target, count, providers = {}) {
  if (!target) return;
  count = integer(count, 'melee signal count');
  if (count < 0) throw new Error('Native negative melee signal count is unsupported');
  requireProviders(providers, ['enqueue', 'createDamageEffect', 'hasFeat', 'attackWeapon']);
  let index = (actor.combatRound.currentAttack & 255) - count, attackDelay = 0;
  let record = getAttackData(actor.combatRound, index, providers.warning), impactDelay = record.animationDuration >>> 1;
  // Validate all payload dependencies before emitting any event.
  for (let i = 0; i < count; i++) {
    const data = getAttackData(actor.combatRound, index + i, providers.warning);
    if (attackResultDoesDamage(data.result) && data.lists[2].length) requireProviders(providers, ['effectTarget']);
    if (!attackResultDoesDamage(data.result) && data.lists[3].some(Boolean)) requireProviders(providers, ['messageType', 'messageInteger']);
  }
  await providers.preflight?.(actor, target, count);
  for (let i = 0; i < count; i++, index++) {
    record = getAttackData(actor.combatRound, index, providers.warning);
    await providers.enqueue(15, actor.id, target.id, attackDelay, copyAttackData(record, 1));
    if (record.attackType === 9) await providers.enqueue(20, actor.id, actor.id, attackDelay, record.targetId);
    if (!await providers.hasFeat(actor, 21) && !await providers.attackWeapon(actor, record.weaponAttackType) && record.attackType !== 65002)
      await providers.enqueue(20, actor.id, actor.id, attackDelay, target.id);
    if (attackResultDoesDamage(record.result)) {
      const values = Array(39).fill(0);
      for (let component = 0; component < 32; component++) values[component] = record.damage[component];
      values[32] = 1; values[33] = record.animationDuration >>> 1; values[36] = 1;
      const damage = await providers.createDamageEffect(actor.id, values, record.strings[1]);
      for (let message = record.lists[3].length - 1; message >= 0; message--)
        await providers.enqueue(22, actor.id, target.id, impactDelay, record.lists[3][message]);
      await providers.enqueue(5, actor.id, target.id, impactDelay, damage);
      for (const effect of record.lists[0]) await providers.enqueue(5, actor.id, target.id, impactDelay, effect);
      for (const effect of record.lists[1]) await providers.enqueue(19, actor.id, actor.id, impactDelay, effect);
      for (const effect of record.lists[2]) {
        const id = integer(await providers.effectTarget?.(effect), 'effect target ID') >>> 0;
        await providers.enqueue(19, id, id, impactDelay, effect);
      }
    } else {
      for (let message = record.lists[3].length - 1; message >= 0; message--) {
        const payload = record.lists[3][message];
        if (payload && await providers.messageType?.(payload) === 2 && await providers.messageInteger?.(payload, 0) === 234)
          await providers.enqueue(22, actor.id, target.id, impactDelay, payload);
      }
    }
    const increment = record.attackDuration >>> 1;
    attackDelay = (attackDelay + increment) >>> 0; impactDelay = (impactDelay + increment) >>> 0;
  }
}
// SignalRangedDamage 0x1403edcc0 uses projectile travel (+8), schedules all
// feedback even on misses, and advances by animationDuration/2 (+2).
export async function signalRangedDamage(actor, target, count, providers = {}) {
  if (!target) return;
  count = integer(count, 'ranged signal count');
  if (count < 0) throw new Error('Native negative ranged signal count is unsupported');
  requireProviders(providers, ['enqueue', 'createDamageEffect', 'difficulty', 'safeProjectile', 'ammunition']);
  let index = (actor.combatRound.currentAttack & 255) - count, attackDelay = 0;
  let record = getAttackData(actor.combatRound, index, providers.warning);
  let impactDelay = (record.reactionDelay + (record.animationDuration >>> 1)) >>> 0;
  for (let i = 0; i < count; i++) {
    const data = getAttackData(actor.combatRound, index + i, providers.warning);
    if (attackResultDoesDamage(data.result) && data.lists[2].length) requireProviders(providers, ['effectTarget']);
  }
  await providers.preflight?.(actor, target, count);
  for (let i = 0; i < count; i++, index++) {
    record = getAttackData(actor.combatRound, index, providers.warning);
    await providers.enqueue(15, actor.id, target.id, attackDelay, copyAttackData(record, 1));
    if (integer(await providers.difficulty(1), 'ranged difficulty option') === 0 || !actor.isPC && !actor.isPossessedFamiliar)
      await providers.enqueue(20, actor.id, actor.id, attackDelay, null);
    const releaseDelay = ((record.animationDuration >>> 1) + attackDelay) >>> 0;
    await providers.safeProjectile(actor, releaseDelay, index);
    await providers.ammunition(actor, (releaseDelay + 1) >>> 0);
    for (let message = record.lists[3].length - 1; message >= 0; message--)
      await providers.enqueue(22, actor.id, target.id, impactDelay, record.lists[3][message]);
    if (attackResultDoesDamage(record.result)) {
      const values = Array(39).fill(0);
      for (let component = 0; component < 32; component++) values[component] = record.damage[component];
      values[33] = record.animationDuration >>> 1; values[36] = 1; values[37] = 1;
      await providers.enqueue(5, actor.id, target.id, impactDelay,
        await providers.createDamageEffect(actor.id, values, record.strings[1]));
      for (const effect of record.lists[0]) await providers.enqueue(5, actor.id, target.id, impactDelay, effect);
      for (const effect of record.lists[1]) await providers.enqueue(19, actor.id, actor.id, impactDelay, effect);
      for (const effect of record.lists[2]) {
        const id = integer(await providers.effectTarget(effect), 'effect target ID') >>> 0;
        await providers.enqueue(19, id, id, impactDelay, effect);
      }
    }
    attackDelay = (attackDelay + (record.animationDuration >>> 1)) >>> 0;
    impactDelay = (record.reactionDelay + (record.animationDuration >>> 1) + attackDelay) >>> 0;
  }
}

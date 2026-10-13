import { OBJECT_INVALID } from './game_object_array.js';

// CNWSCombatAttackData: ctor 0x140373d20, ClearAttackData 0x1403756c0.
// This is local storage, not a pointer layout or network serialization. Keep
// unresolved scalars by offset. Zero initialization of padding is local only.
const fields = {
  group: [0, 'Uint8'], animationDuration: [2, 'Uint16'], targetId: [4, 'Uint32'],
  reactionDelay: [8, 'Uint16'], reactionAnimation: [10, 'Uint16'], attackDuration: [12, 'Uint16'],
  roll: [0x0e, 'Uint8'], confirmation: [0x0f, 'Uint8'], modifier: [0x10, 'Int32'], missedBy: [0x14, 'Uint8'],
  weaponAttackType: [0x56, 'Uint8'], combatMode: [0x57, 'Uint8'],
  concealmentChance: [0x58,'Uint8'],
  ranged: [0x5c, 'Int32'], sneakAttack: [0x60, 'Int32'], deathAttack: [0x64, 'Int32'], killingBlow: [0x68, 'Int32'],
  coupDeGrace: [0x6c, 'Int32'], threatened: [0x70, 'Int32'], deflected:[0x74,'Int32'], result: [0x78, 'Uint8'], attackType: [0x7a, 'Uint16'],
  specialParameter: [0x7c, 'Uint16']
};
export function createAttackData() {
  const data = { raw: new DataView(new ArrayBuffer(0xf0)),
    strings: ['', ''], lists: Array.from({ length: 4 }, () => []) };
  data.damage = new Int16Array(data.raw.buffer, 0x16, 32);
  for (const [name, [offset, type]] of Object.entries(fields)) Object.defineProperty(data, name, {
    enumerable: true, get: () => data.raw[`get${type}`](offset, true),
    set: value => data.raw[`set${type}`](offset, value, true)
  });
  return clearAttackData(data);
}
// SetBaseDamage 0x140379b00..140379b05 writes component 12, independent
// of the physical weapon damage flags. GetTotalDamage(nonzero) skips 0..2.
export function setBaseAttackDamage(data, amount) { data.damage[12] = (amount << 16) >> 16; }
export function totalAttackDamage(data, excludePhysical = 0) {
  if (data.damage?.length !== 32) throw new Error('Native attack damage components are unavailable');
  let total = 0;
  for (let index = excludePhysical === 0 ? 0 : 3; index < 32; index++) {
    const amount = (data.damage[index] << 16) >> 16;
    if (amount >= 0) total = (total + amount) | 0;
  }
  return total;
}
export function clearAttackData(data) {
  const raw = data.raw;
  raw.setUint8(0, 255); raw.setUint16(2, 0, true);
  raw.setBigUint64(4, BigInt(OBJECT_INVALID), true); raw.setBigUint64(12, 0n, true);
  raw.setUint8(0x14, 0); data.damage.fill(-1);
  raw.setUint8(0x56, 0); raw.setUint16(0x57, 0, true); raw.setInt32(0x5c, 0, true);
  for (const offset of [0x60, 0x68, 0x70, 0x80]) raw.setBigUint64(offset, 0n, true);
  raw.setUint8(0x78, 0); raw.setUint32(0x7a, 0xff0000, true);
  raw.setUint32(0x88, 0, true); raw.setUint32(0x8c, OBJECT_INVALID, true);
  for (const offset of [0x90, 0x98, 0xa0, 0xa8]) raw.setBigUint64(offset, 0n, true);
  data.strings.fill('');
  for (let i = 0; i < 4; i++) { data.lists[i].length = 0; raw.setInt32(0xb8 + i * 16, 0, true); }
  return data;
}
// GetAttack 0x140375e40: >=50 clamps to slot 49. Negative indices would
// access native memory outside the pool; diagnose rather than fabricate data.
export function getAttackData(round, index, warning = () => {}) {
  index |= 0;
  if (index < 0) throw new Error('Native negative combat attack index is unsupported');
  if (index >= 50) { warning('Native warning: Error! Attempting to access out of bounds combat information!'); index = 49; }
  if (round.attacks?.length !== 50) throw new Error('Native fixed combat attack pool is unavailable');
  return round.attacks[index];
}
export function clearAllAttacks(round) {
  if (round.attacks?.length !== 50) throw new Error('Native fixed combat attack pool is unavailable');
  for (const data of round.attacks) clearAttackData(data);
}
// ClearAllSpecialAttacks 0x140375570. Already consumed records are retained.
export function clearAllSpecialAttacks(round, warning) {
  const total = (round.onhandAttacks + round.offhandAttacks + round.additionalAttacks + round.bonusEffectAttacks) | 0;
  const count = total > 1 ? total & 255 : 1;
  for (let i = round.currentAttack & 255; i < count; i++) getAttackData(round, i, warning).attackType = 0;
  round.specialAttacks.length = 0;
}
// UpdateAttackTargetForAllActions 0x14037a140.
export function updateRoundAttackTargets(round, targetId) {
  for (const action of round.actions) if ((action.nativeActionType & 255) === 1 && action.followTarget === 1)
    action.targetId = targetId >>> 0;
}
// Copy 0x1403757d0 copies scalars and optionally strings, never the four
// effect/message lists. Scheduled attack data owns a separate record.
export function copyAttackData(source, copyStrings = 1) {
  const target = createAttackData();
  const ranges = [[0, 1], [2, 12], [12, 20], [0x14, 0x15], [0x16, 0x59], [0x5c, 0x79], [0x7a, 0x7e], [0x80, 0x90]];
  for (const [start, end] of ranges) for (let i = start; i < end; i++) target.raw.setUint8(i, source.raw.getUint8(i));
  if (copyStrings === 1) target.strings.splice(0, 2, ...source.strings);
  return target;
}

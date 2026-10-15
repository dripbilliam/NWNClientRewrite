import { getAttackData } from './combat_attack_data.js';
import { attackResultDoesDamage } from './combat_strike.js';

// ResolveMeleeSpecialAttack1403e6660..1403e7837. These eleven IDs are
// branches compiled into this target engine, not module/2DA exceptions.
// All other ushort IDs fall through after normal resolution/animation.
const extraEffectTypes = new Set([9, 16, 17, 23, 31, 39, 296, 301, 472, 65000, 65001]);
export async function resolveMeleeSpecialAttack(actor, index, count, target, duration, p) {
  if (!target) return;
  const required = name => { if (typeof p[name] !== 'function') throw new Error(`Native melee special provider ${name} is unavailable`); return p[name]; };
  const record = getAttackData(actor.combatRound, actor.combatRound.currentAttack & 255, p.warning);
  // Virtual creature cast occurs twice on a successful first cast, before
  // remaining-use lookup. Preserve order for providers with observable reads.
  const creature = required('asCreature')(target) ? required('asCreature')(target) : null;
  if ((record.attackType & 65535) < 1116) {
    const uses = await required('remainingUses')(actor, record.attackType & 65535);
    if (!Number.isInteger(uses)) throw new Error('Native melee special remaining uses are unavailable');
    if ((uses & 255) === 0) record.attackType = 0;
  }
  await required('attackRoll')(actor, target);
  if (attackResultDoesDamage(record.result)) {
    await required('damage')(actor, target); await required('postDamage')(actor, target);
  }
  await required('animations')(actor, index, count, target, duration, record);
  if (extraEffectTypes.has(record.attackType & 65535)) await required('specialEffect')(actor, target, creature, record);
}

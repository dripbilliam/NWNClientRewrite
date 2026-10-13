import { intEntry, rulesetInt } from './combat_stats.js';
import { creatureRoot } from './creature_rules.js';
import { attackWeapon, currentAttackWeapon, weaponRule, criticalProfile } from './combat_weapon.js';
import { unarmedDamageProfile } from './unarmed_damage.js';
import { damageBonus } from './damage_bonus.js';
import { weightedDamageAmount } from './damage_weight.js';
import { damageEffectBonus } from './damage_effect_bonus.js';
import { equipmentCombatEffects } from './combat_modifiers.js';

const i16 = value => (value << 16) >> 16;
const range = (first, last) => Array.from({ length: last - first + 1 }, (_, i) => first + i);
const highestTier = (feats, ids) => {
  for (let i = ids.length - 1; i >= 0; i--) if (feats.includes(ids[i])) return i + 1;
  return 0;
};

// Native GetDamageRoll's ladders query fixed engine feat IDs. They are not
// inferred from class levels or campaign content. Separate stacking ladders
// and pending feat state must remain visible to callers.
export function sneakDamageDice(feats, pendingFeats = []) {
  feats = [...feats, ...pendingFeats];
  return highestTier(feats, range(842, 851)) + highestTier(feats, [221, ...range(345, 353), ...range(1032, 1041)]) +
    highestTier(feats, [460, 461, 462, ...range(1007, 1018)]);
}
export const deathDamageDice = (feats, pendingFeats = []) => highestTier([...feats, ...pendingFeats], [...range(455, 459), ...range(1004, 1006), ...range(1019, 1030)]);

export function damageDifficulty(actor, target, getOption) {
  let playerToNpc = 0, npcToPlayer = 0, percentage = 100;
  if (target?.objectType === 5) {
    const isPc = creatureRoot(actor).IsPC, targetPc = target.isPC || target.isPossessedFamiliar;
    if (isPc === 1 && !targetPc) { playerToNpc = 1; percentage = getOption(3); }
    else if (isPc === 0 && targetPc) { npcToPlayer = 1; percentage = getOption(4); }
  }
  return { playerToNpc, npcToPlayer, percentage };
}

function propertyDice(table, costValue) {
  if (!table) throw new Error('Native damage item property dice rules are unavailable');
  return { dice: intEntry(table, costValue & 65535, 'NumDice').value, sides: intEntry(table, costValue & 65535, 'Die').value };
}

// GetDamageRoll 0x1403fee20..0x1404009d0. Callers must supply the native
// mitigation queries; an unavailable query is never treated as zero. Physical
// effect bonuses use the shared native provider unless explicitly supplied.
// This provider resolves damage but does not apply HP or emit lifecycle events.
function* damageRollSteps(actor, target, rules, items, random, {
  attack, offhand = false, critical = false, sneak = false, death = false, maximize = false,
  difficulty, effectBonus, damageFlags, damagePower, immunity, resistance, reduction, pendingFeats = [], effectLimit = 100, versus, weaponAttackType
}) {
  if (effectBonus === undefined && !rules.iprp_damagecost) throw new Error('Native damage effect cost rules are unavailable');
  const queryEffects = effectBonus ?? (context => damageEffectBonus(actor, target, rules, items, random, {
    ...context, limit: effectLimit, versus,
    effects: [...(actor.itemCombatEffects ?? equipmentCombatEffects(items, rules, { root: creatureRoot(actor) })).effects, ...(actor.effects ?? [])]
  }).total);
  if (!attack || !['weaponAttackType', 'ranged', 'attackType'].every(field => Number.isInteger(attack[field])) ||
    !difficulty || !['playerToNpc', 'npcToPlayer', 'percentage'].every(field => Number.isInteger(difficulty[field])) ||
    typeof queryEffects !== 'function' || typeof damageFlags !== 'function' || typeof weaponAttackType!=='function' ||
    target && [damagePower, immunity, resistance, reduction].some(query => typeof query !== 'function')) throw new Error('Native damage resolution providers are unavailable');
  const selectHand=()=>{const hand=weaponAttackType();if(!Number.isInteger(hand))throw new Error('Native damage weapon selection is unavailable');return hand|0;};
  // 1403feef2: GetCurrentAttackWeapon(0), NOT the record's cached hand.
  // Armed branches query GetWeaponAttackType again at 1403fefbe and,
  // for maximized non-natural damage, 1403ff454. Preserve natural RNG draws.
  const weapon = offhand ? attackWeapon(items, rules, true) : currentAttackWeapon(items, rules, 0,selectHand);
  const unarmed = !weapon || [36, 78].includes(weapon.data.BaseItem);
  const natural = !unarmed&&[3, 4, 5].includes(selectHand());
  const multiplier = critical ? criticalProfile(actor, items, rules, offhand).multiplier : 1;
  const overwhelming = actor.stats.feats.includes(weaponRule(weapon, rules, 'EpicWeaponOverwhelmingCriticalFeat', weapon ? 65535 : 720) & 65535);
  const weighted = (roll, maximum) => weightedDamageAmount(random, roll, maximum,
    difficulty.playerToNpc, difficulty.npcToPlayer, difficulty.percentage);
  let profile = { dice: 0, sides: 0 }, base = 0, naturalPropertyPresent = false;
  if (unarmed) profile = unarmedDamageProfile(actor, rules);
  else if (natural) {
    const property = weapon.data.PropertiesList?.find(p => p.PropertyName === 77);
    if (property && (property.CostValue & 65535)) {
      naturalPropertyPresent = true;
      profile = propertyDice(rules.iprp_monstcost, property.CostValue);
    }
  } else if (maximize && [7, 8].includes(selectHand())) profile = unarmedDamageProfile(actor, rules);
  else profile = { dice: weaponRule(weapon, rules, 'NumDice') & 255, sides: weaponRule(weapon, rules, 'DieToRoll') & 255 };
  const overwhelmingRoll = () => random.dice(rulesetInt(rules, 'EPIC_OVERWHELMING_CRITICAL_DIE', 1),
    rulesetInt(rules, 'EPIC_OVERHWLEMING_CRITICAL_NUM_DICE', 6));
  const ordinaryRoll = () => {
    const roll = random.dice(profile.dice, profile.sides);
    // GetUnarmedDamageRoll weights unsigned dice; weapons narrow both values
    // to signed short before invoking the same weighting routine.
    return unarmed ? weighted(roll, profile.dice * profile.sides) : weighted(i16(roll), i16(i16(profile.dice) * i16(profile.sides)));
  };
  if ((unarmed && critical) || !maximize) {
    // A missing natural damage property rolls no base dice in the native path.
    if (unarmed || !natural || naturalPropertyPresent) for (let i = 0; i < multiplier; i++) {
      base = (base + ordinaryRoll()) & 65535;
      if (critical && overwhelming) base = (base + overwhelmingRoll()) & 65535;
    }
  } else {
    base = Math.imul(i16(profile.dice), i16(profile.sides));
    if (critical) {
      for (let i = 1; i < multiplier; i++) base = (base + random.dice(profile.dice, profile.sides)) & 65535;
      if (overwhelming) base = (base + overwhelmingRoll()) & 65535;
    }
  }
  if (!unarmed && weapon.data.PropertiesList?.some(p => p.PropertyName === 47)) base = 0;
  let total = base;
  const sneakAmount = sneak ? random.dice(sneakDamageDice(actor.stats.feats, pendingFeats), 6) : 0;
  total = (total + sneakAmount) & 65535;
  const deathAmount = death ? random.dice(deathDamageDice(actor.stats.feats, pendingFeats), 6) : 0;
  total = (total + deathAmount) & 65535;
  const bonus = damageBonus(actor, target?.objectType === 5 ? target : null, rules, items, random, { attack, offhand, selectHand });
  for (let i = 0; i < multiplier; i++) total = (total + bonus.total) & 65535;
  let massive = 0;
  if (critical) {
    const property = weapon?.data.PropertiesList?.find(p => p.PropertyName === 74);
    if (property && (property.CostValue & 65535)) {
      const dice = propertyDice(rules.iprp_damagecost, property.CostValue);
      massive = dice.dice ? random.dice(dice.dice, dice.sides) : dice.sides;
      total = (total + massive) & 65535;
    }
  }
  // GetTotalEffectBonus queries the current attack itself. Its result already
  // includes critical multiplication; the caller must not multiply it again.
  // Native GetDamageRoll passes param_9=0 even for offhand damage. Its effect
  // query therefore uses the main-hand critical profile and fallback hand.
  const effects = (yield queryEffects({ maximize, target, attack, offhand: false, critical,
    criticalMultiplier: critical ? criticalProfile(actor, items, rules, false).multiplier : 1 })) | 0;
  total = i16(total + effects);
  if (total < effects) total = i16(effects);
  if (total < 1) total = 1;
  const beforeMitigation = total, flags = damageFlags();
  if (target) {
    const power = damagePower({ offhand, target });
    total = i16(yield immunity(total, flags, { simulation: maximize, combat: true }));
    total = i16(yield resistance(total, flags, { simulation: maximize, combat: true, baseWeapon: true, ranged: attack.ranged }));
    total = i16(yield reduction(total, power, { simulation: maximize, combat: true, ranged: attack.ranged }));
    if (total < 0) total = 0;
  }
  return { amount: total, beforeMitigation, base: i16(base), sneak: sneakAmount, death: deathAmount,
    bonus, massive, effects, flags, criticalMultiplier: multiplier, profile };
}

export function damageRoll(...args) {
  const steps = damageRollSteps(...args); let step = steps.next();
  while (!step.done) {
    if (step.value?.then) throw new Error('Synchronous damage roll received an asynchronous provider');
    step = steps.next(step.value);
  }
  return step.value;
}
// The live VM must await immediate resistance-budget removal before querying
// reduction. Reuse the same native algorithm and random order as the pure API.
export async function damageRollAsync(...args) {
  const steps = damageRollSteps(...args); let step = steps.next();
  while (!step.done) step = steps.next(await step.value);
  return step.value;
}

const i16 = value => (value << 16) >> 16;

// CNWSObject::GetCurrentHitPoints 0x140495130. Fields are stored as int32,
// whereas both the base-only and total getters return signed short.
export function creatureCurrentHitPoints(state, baseOnly = 0) {
  if (!state || !Number.isInteger(state.baseHP) || !Number.isInteger(state.temporaryHP)) throw new Error('Native creature hit point state is unavailable');
  return i16(baseOnly === 1 ? state.baseHP : (state.baseHP + state.temporaryHP) | 0);
}

// GetDead 0x1404953b0 / GetIsPCDying 0x140495620 both use total HP.
export function creatureLifeState(state, isPC, possessedFamiliar = false) {
  const hp = creatureCurrentHitPoints(state), player = Boolean(isPC || possessedFamiliar);
  return { dead: hp < (player ? -9 : 1), dying: player && hp < 1 && hp > -10 };
}

// CNWSCreature::DoDamage 0x14038a930..0x14038aaa5. A local authority primitive;
// callers must supply live effect removal and difficulty/life-state queries.
// Removing a temporary HP effect can itself trigger dying/death, so it cannot
// be replaced with a deferred removal or a single subtraction of aggregate HP.
// This function does not implement OnApplyDamage or its surrounding events.
function* damageSteps(state, amount, {
  getTemporaryEffects, removeEffectImmediate, getDifficulty, getLifeFlags
}) {
  creatureCurrentHitPoints(state);
  if (!Number.isInteger(amount) || [getTemporaryEffects, removeEffectImmediate, getDifficulty, getLifeFlags]
    .some(provider => typeof provider !== 'function')) throw new Error('Native creature damage providers are unavailable');
  amount |= 0;
  const before = creatureCurrentHitPoints(state);
  let absorbed = 0;
  if (i16(state.temporaryHP) > 0) {
    let remaining = 0, index = 0, effects = getTemporaryEffects();
    while (index < effects.length) {
      const effect = effects[index];
      if (effect.type !== 15) throw new Error('Temporary HP provider returned a different effect type');
      const capacity = effect.integers[0] | 0;
      if (amount < capacity) {
        effect.integers[0] = (capacity - amount) | 0;
        remaining = (remaining + effect.integers[0]) | 0;
        absorbed = (absorbed + amount) | 0;
        amount = 0; index++;
      } else {
        amount = (amount - capacity) | 0; absorbed = (absorbed + capacity) | 0;
        yield effect.id;
        effects = getTemporaryEffects(); index = 0;
        if (effects.some(e => e.id === effect.id)) throw new Error('Immediate temporary HP removal did not remove its live handle');
      }
    }
    state.temporaryHP = remaining;
  }
  // Query after removal: callbacks can change life flags or difficulty.
  const difficulty = getDifficulty(5), flags = getLifeFlags();
  if (!Number.isInteger(difficulty) || !flags || !Number.isInteger(flags.immortal)) throw new Error('Creature damage life/difficulty state is unavailable');
  const base = creatureCurrentHitPoints(state, 1);
  if ((difficulty === 1 && (flags.isPC || flags.possessedFamiliar) || flags.immortal === 1) &&
    ((base - amount) | 0) < 1) amount = Math.max(0, base - 1);
  state.baseHP = (base - amount) | 0;
  return { before, after: creatureCurrentHitPoints(state), damageToBase: amount, absorbed,
    baseHP: state.baseHP, temporaryHP: state.temporaryHP };
}

export function doCreatureDamage(state, amount, providers) {
  const steps = damageSteps(state, amount, providers);
  let step = steps.next();
  while (!step.done) {
    const result = providers.removeEffectImmediate(step.value);
    if (result?.then) throw new Error('Synchronous damage received an asynchronous removal provider');
    step = steps.next();
  }
  return step.value;
}

// The browser VM is asynchronous. Await each native immediate removal before
// continuing the SAME algorithm, including its live-list restart behavior.
export async function doCreatureDamageAsync(state, amount, providers) {
  const steps = damageSteps(state, amount, providers);
  let step = steps.next();
  while (!step.done) {
    await providers.removeEffectImmediate(step.value);
    step = steps.next();
  }
  return step.value;
}

// ExecuteCommandEffectDamage 0x140518c70, GetDamageIndexFromFlags
// 0x1402a3b60 and GetHighestDamageTypeFlag 0x1402a3c00.
export function highestDamageTypeFlag(damageTypeCount) {
  if (!Number.isInteger(damageTypeCount) || damageTypeCount < 0) throw new Error('Damage type rules are unavailable');
  const count = damageTypeCount > 32 ? 0 : damageTypeCount;
  const top = (1 << ((count - 1) & 31)) >>> 0;
  return ((top - 1) | top) >>> 0;
}

export function damageEffectIntegers(amount, flags = 3, power = 0, damageTypeCount) {
  const highest = highestDamageTypeFlag(damageTypeCount);
  amount |= 0; flags |= 0; power |= 0;
  if ((amount >>> 0) > 10000) amount = 1;
  if (flags < 0 || (flags >>> 0) > highest) flags = 1;
  if (power < 0 || power > 22) power = 0;
  const integers = Array(39).fill(0);
  integers.fill(-1, 0, 32);
  const index = flags > 1 ? 31 - Math.clz32(flags) : 0;
  integers[index] = amount;
  integers[33] = 1000; integers[34] = flags; integers[35] = power;
  return integers;
}

// ExecuteCommandEffectDamageImmunityIncrease/Decrease 0x140519140/140518ff0.
// Decrease accepts negative constructor values, but OnApply rejects them.
export function damageImmunityEffectIntegers(flags, percentage, increase, damageTypeCount) {
  flags |= 0; percentage |= 0;
  if (flags < 0 || (flags >>> 0) > highestDamageTypeFlag(damageTypeCount)) flags = 8;
  percentage = Math.min(100, Math.max(increase ? 0 : -100, percentage));
  return [flags, percentage];
}

// ExecuteCommandEffectDamageResistance 0x1405195c0 preserves signed amount,
// budget and condition. Reduction 0x140519410 clamps amount/budget to zero.
export function damageResistanceEffectIntegers(flags, amount, limit, rangedOnly, damageTypeCount) {
  flags |= 0;
  if (flags < 0 || (flags >>> 0) > highestDamageTypeFlag(damageTypeCount)) flags = 8;
  return [flags, amount | 0, limit | 0, rangedOnly | 0];
}

export function damageReductionEffectIntegers(amount, power, limit, rangedOnly) {
  power |= 0;
  return [Math.max(0, amount | 0), power < 0 || power > 22 ? 0 : power, Math.max(0, limit | 0), rangedOnly | 0];
}

// SetDamageImmunity 0x14049ae80 writes only the LOWEST flagged cache byte.
export function setDamageImmunity(cache, flags, percentage) {
  if (!cache || cache.length !== 32) throw new Error('Native damage immunity cache is unavailable');
  flags >>>= 0; percentage |= 0;
  for (let i = 0; i < 32; i++) if ((flags >>> i) & 1) {
    cache[i] = Math.min(100, Math.max(-100, percentage));
    return;
  }
}

// The apply/remove handlers recompute from effects with exactly equal flags.
// They never combine partially overlapping flag sets or subtract from a
// previously capped cache entry.
export function damageImmunityTotal(effects, flags) {
  let total = 0;
  for (const effect of effects) if ([16, 17].includes(effect.type) && (effect.integers[0] >>> 0) === (flags >>> 0))
    total = (total + (effect.type === 16 ? 1 : -1) * (effect.integers[1] | 0)) | 0;
  return total;
}

// GetDamageImmunityByFlags 0x140495180..0x14049528f. The cache is signed
// byte data. Native chooses the lowest percentage across flags; Red Dragon
// immunity feat 964 intercepts any attack whose flags include fire (bit 8).
export function damageImmunityByFlags(flags, cache, feats = []) {
  flags >>>= 0;
  if (flags & 256 && feats.includes(964)) return 100;
  if (!cache || cache.length !== 32) throw new Error('Native damage immunity cache is unavailable');
  let value = 0, found = false;
  for (let i = 0; i < 32; i++) if ((flags >>> i) & 1) {
    const byte = (cache[i] << 24) >> 24;
    const percentage = Math.max(-100, Math.min(100, byte));
    if (!found || percentage < value) value = percentage;
    found = true;
  }
  return value;
}

// DoDamageImmunity 0x140491690..0x14049194b. Positive percentages absorb
// at least one point, even on zero incoming damage. Caller clamps later.
export function damageAfterImmunity(amount, percentage) {
  amount |= 0; percentage = (percentage << 24) >> 24;
  let absorbed = Math.trunc(Math.imul(percentage, amount) / 100) | 0;
  if (percentage > 0) absorbed = Math.max(1, absorbed);
  return (amount - absorbed) | 0;
}

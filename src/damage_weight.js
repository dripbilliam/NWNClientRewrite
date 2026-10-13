// CNWRules::GetWeightedDamageAmount 0x1402a4220..0x1402a4341.
// This provider expects the original raw roll and maximum dice damage. Native
// callers choose direction and percentage from difficulty; bonuses and damage
// mitigation belong to the caller. All intermediate products are signed int32.
export function weightedDamageAmount(random, roll, maximum, playerToNpc, npcToPlayer, percentage) {
  roll |= 0; maximum |= 0; playerToNpc |= 0; npcToPlayer |= 0; percentage |= 0;
  const divide100 = value => Math.trunc(value / 100) | 0;
  const remainder = divisor => {
    const value = random.next();
    if (!divisor) throw new Error('Damage difficulty rules cause a native integer division fault');
    return value % divisor;
  };
  if (playerToNpc === 1) {
    if (percentage !== 0) {
      if (divide100(Math.imul(maximum, percentage)) === maximum) return maximum;
      // The native short circuit above also handles 100%, including maximum=0.
      const fraction = remainder((100 - percentage) | 0);
      const amount = (divide100(Math.imul((fraction + percentage) | 0, maximum)) + roll) | 0;
      return Math.min(maximum, amount);
    }
  } else if (npcToPlayer === 1 && percentage !== 0) {
    if (percentage < 100) return Math.max(1, (roll - divide100(Math.imul((100 - percentage) | 0, maximum))) | 0);
    if (percentage !== 100) return (divide100(Math.imul(remainder((percentage - 100) | 0), maximum)) + roll) | 0;
  }
  return roll;
}

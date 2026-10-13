// CNWSCombatAttackData::AddDamage 0x140374810. Each attack owns 32 signed
// short components. An existing positive component is floored at ONE after a
// penalty, whereas an empty/nonpositive component accepts a floor of ZERO.
export function addAttackDamage(attack, flags, amount) {
  if (!(Array.isArray(attack.damage) || attack.damage instanceof Int16Array) || attack.damage.length !== 32) throw new Error('Native attack damage record is unavailable');
  flags >>>= 0; amount |= 0;
  const index = flags > 1 ? 31 - Math.clz32(flags) : 0;
  const stored = (attack.damage[index] << 16) >> 16;
  const value = stored < 1 ? Math.max(0, amount) : Math.max(1, (stored + amount) | 0);
  attack.damage[index] = (value << 16) >> 16;
}

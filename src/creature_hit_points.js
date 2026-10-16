import { rulesetInt } from './combat_stats.js';

const i16 = n => (n << 16) >> 16;
const featSet = (root,bonus) => new Set([...(root.FeatList ?? []).map(f => f.Feat),...bonus]);

// CNWSCreature::GetMaxHitPoints 0x140391850. NPCs/possessed familiars
// have an aggregate stored base; PCs have per-level hit dice. Neither uses
// the serialized MaxHitPoints snapshot as the live maximum.
export function creatureMaxHitPoints(root, constitutionModifier, rules, { possessedFamiliar = false, includeFeatBonuses = true,bonusFeats=[] } = {}) {
  const level = root.ClassList.reduce((n, c) => n + c.ClassLevel, 0) & 255;
  const feats = featSet(root,bonusFeats), has = id => feats.has(id);
  const constant = (name, fallback) => rulesetInt(rules, name, fallback);
  const toughness = includeFeatBonuses && has(40) ? constant('FEAT_TOUGHNESS_HP_BONUS', 1) : 0;
  let epic = 0;
  for (let tier = 10; tier >= 1; tier--) if (has(753 + tier)) {
    epic = i16(constant(`FEAT_EPIC_TOUGHNESS_HP_BONUS_${tier}`, tier * 20)); break;
  }
  const pale = root.ClassList.find(c => c.Class === 34)?.ClassLevel ?? 0;
  const vigor = constant('FEAT_DEATHLESS_VIGOR_HP_BONUS', 3);
  const epicVigor = constant('FEAT_EPIC_DEATHLESS_VIGOR_HP_BONUS', 5);
  if (root.IsPC && !possessedFamiliar) {
    let hp = (root.LvlStatList ?? []).slice(0, level).reduce((n, l) => (n + Math.max(1, (l.LvlStatHitDie & 255) + constitutionModifier) + toughness) | 0, 0);
    if (has(891) && pale > 4 && includeFeatBonuses) hp = i16(hp + i16(vigor) * (Math.min(10, pale) - 4));
    if (has(891) && pale > 10) hp = i16(hp + i16(epicVigor) * Math.trunc((pale - 10) / 5));
    return i16(hp + epic);
  }
  // The NPC branch really uses max(pale,10), not the PC min(pale,10)-4.
  // It also applies Deathless Vigor independently of includeFeatBonuses.
  const deathless = has(891) ? i16(i16(vigor) * Math.max(pale, 10) + (pale > 10 ? i16(epicVigor) * Math.trunc((pale - 10) / 5) : 0)) : 0;
  const storedBase = i16(root.HitPoints);
  return i16(Math.max(level, storedBase + constitutionModifier * level) + level * i16(toughness) + deathless + epic);
}

// ReadStatsFromGff 0x140411641..0x140411948 preserves injury while restoring
// CON and subsequently adding feat HP. Live refresh passes currentHP instead.
export function restoredCreatureHitPoints(root, maximum, constitutionModifier) {
  const base = i16(root.HitPoints), current = i16(root.CurrentHitPoints ?? base);
  if (root.IsPC) return i16(current + maximum - base);
  const level = root.ClassList.reduce((n, c) => n + c.ClassLevel, 0) & 255;
  if (current < base || base + constitutionModifier * level > level) return i16(maximum + current - base);
  return maximum;
}

import { creatureAlignment } from './creature_rules.js';

// ExecuteCommandGetIsImmune1405271d0. Category INT guard is1..32 before
// narrowing; missing/noncreature subjects return0, versus lookup is optional.
export function scriptGetIsImmune(args,p){
  const [id,category,versus=0x7f000000]=args;
  if(![id,category,versus].every(Number.isInteger))throw new Error('Native GetIsImmune arguments are unavailable');
  const source=p.creature(versus>>>0),actor=p.creature(id>>>0),kind=category|0;
  return actor&&kind>0&&kind<33?p.immunity(actor,kind&255,source,1):0;
}

// GetEffectImmunity 0x140400ab0. Native built-in feats supplement effect type
// 22; plot grants immunity even when the caller excludes feat checks.
export function effectImmunity(root, effects, category, versus = null, { includeFeats = true, plot = Boolean(root.Plot) } = {}) {
  if (plot) return true;
  const feats = new Set((root.FeatList ?? []).map(f => f.Feat));
  const featImmunities = { 31: [896], 6: [963, 894], 13: [235], 2: [203, 747, 214], 3: [747, 219, 209], 12: [894], 1: [216], 4: [300] };
  if (includeFeats && featImmunities[category]?.some(f => feats.has(f))) return true;
  const subject = versus ? creatureAlignment(versus) : { race: 28, lawChaos: -1, goodEvil: -1 };
  return effects.some(effect => {
    if (effect.type !== 22) return false;
    const [type, race, law = 0, good = 0] = effect.integers;
    return (!type || type === category) && (race === 28 || race === subject.race) && (!law || law === subject.lawChaos) && (!good || good === subject.goodEvil);
  });
}

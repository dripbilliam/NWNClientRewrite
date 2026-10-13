const f = Math.fround;
import { nativeDistanceSquared } from './nearest_objects.js';

// CNWSCreature::UpdatePersonalSpace uses appearance.2da and a 0.6 default.
export function creatureSpacing(object, appearances) {
  const row = appearances?.rows.get(object.authored?.Appearance_Type);
  const read = (value, fallback) => value === undefined || value === '****' || !Number.isFinite(Number(value)) ? fallback : f(Number(value));
  const personal = read(row?.PERSPACE, f(0.6));
  return { personal, creature: read(row?.CREPERSPACE, personal) };
}

// AIActionDialogObject -> GetIsInUseRange(target, 1.0, false).
// GetUseRange combines CREPERSPACE and the target's combat-target allowance.
export function creatureTalkRange(actor, target, appearances) {
  let range = f(creatureSpacing(actor, appearances).creature + creatureSpacing(target, appearances).creature);
  range = f(range + f(target.combatTargetId !== undefined && target.combatTargetId !== 0x7f000000 ? 0.8 : 0.3));
  return f(range + f(f(1) + f(0.1)));
}

export function horizontalInRange(a, b, range) {
  const dx = f(f(b[0]) - f(a[0])), dy = f(f(b[2]) - f(a[2]));
  return f(f(dy * dy) + f(dx * dx)) <= f(range * range);
}

export function placeableUsePoint(actor, target) {
  const [first, second] = target.actionPoints ?? [];
  if (!first) return target.position;
  return second && nativeDistanceSquared(actor.position, second) <= nativeDistanceSquared(actor.position, first) ? second : first;
}

export function placeableUseRange(actor, appearances) {
  return f(f(creatureSpacing(actor, appearances).personal + f(0.5)) + f(0.1));
}

import { OBJECT_INVALID } from './game_object_array.js';
import { nativeDistanceSquared } from './nearest_objects.js';

const f = Math.fround;
const integer = (v, name) => { if (!Number.isInteger(v)) throw new Error(`Native target ${name} is unavailable`); return v | 0; };
const point = o => {
  if (!Array.isArray(o.position) || o.position.length !== 3 || !o.position.every(Number.isFinite)) throw new Error('Native target position is unavailable');
  return o.position.map(f);
};
const radius = o => {
  if (!Number.isFinite(o.nativePathInfo?.field8)) throw new Error('Native target creature radius is unavailable');
  return f(o.nativePathInfo.field8);
};

// CheckAttackClearLineToTarget1403e2610..1403e282d. Its by-value point
// is raised in place; the horizontal actor position is captured before LOS.
export async function attackClearLine(actor, targetId, targetPoint, area, p) {
  area ??= await p.area(actor);
  const gameObject = await p.object(targetId), target = gameObject && await p.asObject(gameObject);
  if (!target) return 0;
  let to = targetPoint.map(f);
  if (to.every(v => v === f(-10000000))) to = point(target);
  const from = point(actor);
  from[1] = f(from[1] + 1); to[1] = f(to[1] + 1);
  const ranged = integer(await p.ranged(actor), 'ranged flag');
  if (integer(await p.lineOfSight(area, from, to, actor.id, targetId, ranged), 'LOS result') === 0) return 0;
  if (ranged !== 0 || !await p.asCreature(gameObject)) return 1;
  const path = actor.nativePathInfo;
  if (!path || !Number.isFinite(path.field8) || !Number.isInteger(path.field28)) throw new Error('Native target path information is unavailable');
  const saved8 = path.field8, saved28 = path.field28;
  path.field8 = f(0.01); path.field28 = targetId >>> 0;
  try { return integer(await p.creatureLine(area, [from[0], from[2]], [to[0], to[2]], path, 1, 0, null, 1), 'creature-line result'); }
  finally { path.field8 = saved8; path.field28 = saved28; }
}

// GetNearestEnemy140392220..140392805. Walk left BEFORE right from the
// actor's stored array index, shrinking radius by 3D distance minus radii.
// This is not the NWScript nearest-object sorter. Count/IDs are re-read.
export async function nearestEnemy(actor, searchRadius, excludedId, seen, clear, p) {
  searchRadius = f(searchRadius); seen = integer(seen, 'seen flag'); clear = integer(clear, 'clear flag');
  if (!Number.isFinite(searchRadius)) throw new Error('Native target search radius is unavailable');
  const area = await p.area(actor); if (!area) return OBJECT_INVALID;
  let center = -1;
  for (let i = 0; i < p.areaIds(area).length; i++) if ((p.areaIds(area)[i] >>> 0) === (actor.id >>> 0)) { center = i; break; }
  if (center < 0) return OBJECT_INVALID;
  const padding = f(radius(actor) + 10);
  let left = center, right = center, scanLeft = true, scanRight = true, found = OBJECT_INVALID;
  const visit = async (index, direction) => {
    const id = p.areaIds(area)[index]; integer(id, 'area object ID');
    const gameObject = await p.object(id >>> 0);
    if (!gameObject || (id >>> 0) === (actor.id >>> 0) || (id >>> 0) === (excludedId >>> 0)) return false;
    const creature = await p.asCreature(gameObject);
    if (creature && integer(await p.reaction(actor, id >>> 0), 'reaction') === 2 &&
        integer(await p.dead(creature), 'dead flag') === 0 && integer(await p.dying(creature), 'dying flag') === 0) {
      const flags = await p.visibility(actor, gameObject.id);
      if (flags !== null && flags !== undefined) integer(flags, 'visibility flags');
      if (seen === 0 || flags != null && (flags & 1) !== 0) {
        if (clear === 0 || integer(await p.clearLine(actor, gameObject.id, point(creature), area), 'clear-line result') !== 0) {
          const a = point(actor), b = point(creature);
          const dx = f(a[0] - b[0]), dy = f(a[2] - b[2]), dz = f(a[1] - b[1]);
          // magnitude(Vector)1402303d0 sums X then Y then Z (different
          // operand order from GetNewCombatTarget's squared-distance owner).
          const squared = f(f(f(dx * dx) + f(dy * dy)) + f(dz * dz));
          const distance = squared > 0 ? f(Math.sqrt(squared)) : 0;
          const clearance = f(f(distance - radius(actor)) - radius(creature));
          if (clearance < searchRadius) { searchRadius = clearance; found = id >>> 0; }
        }
      }
    }
    const object = await p.asObject(gameObject);
    return Boolean(object && f(direction * f(point(object)[0] - point(actor)[0])) > f(padding + searchRadius));
  };
  while (left >= 0 || right < p.areaIds(area).length) {
    if (scanLeft) { if (left < 0 || await visit(left, -1)) scanLeft = false; }
    if (scanRight) { if (right >= p.areaIds(area).length || await visit(right, 1)) scanRight = false; }
    left--; right++;
  }
  return found;
}

// GetNewCombatTarget1403e39f0..1403e3b2d; the final reach check is strict,
// full 3D, and uses positions captured BEFORE the second MaxAttackRange call.
export async function newCombatTarget(actor, excludedId, p) {
  const range = f(await p.maximumRange(actor, OBJECT_INVALID, 0, 1));
  if (!Number.isFinite(range)) throw new Error('Native target maximum range is unavailable');
  const id = await p.nearestEnemy(actor, f(range + 10), excludedId, 1, 1);
  if ((id >>> 0) === OBJECT_INVALID) return null;
  const gameObject = await p.object(id), object = gameObject && await p.asObject(gameObject);
  if (!gameObject) return null;
  if (!object) throw new Error('Native replacement target object cast is unavailable');
  const from = point(actor), to = point(object);
  const maximum = f(await p.maximumRange(actor, id, 0, 1));
  if (!Number.isFinite(maximum)) throw new Error('Native replacement target maximum range is unavailable');
  return nativeDistanceSquared(from, to) < f(maximum * maximum) ? await p.asCreature(gameObject) : null;
}

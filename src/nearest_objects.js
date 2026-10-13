import { OBJECT_INVALID } from './game_object_array.js';

const f = Math.fround;
export function nativeDistanceSquared(a, b) {
  const dx = f(f(a[0]) - f(b[0])), dy = f(f(a[2]) - f(b[2])), dz = f(f(a[1]) - f(b[1]));
  return f(f(f(dy * dy) + f(dx * dx)) + f(dz * dz));
}

// CNWSArea's X-sorted list, then the native outward search from the reference.
// Equal distances retain encounter order; IDs are never used as a tie breaker.
export function areaObjectsByX(session, area) {
  if (area.nativeSpatial) return Array.from(area.nativeSpatial.view(), id => session.registry.get(id)).filter(Boolean);
  const objects = (area.objects ?? []).map(id => session.registry.get(id)).filter(o => o?.position && o.ownerId === undefined);
  // Native insertion puts a newly added equal-X object ahead of existing ones.
  objects.reverse(); objects.sort((a, b) => f(a.position[0]) - f(b.position[0]));
  return objects;
}

export function areaSpatialIds(session, area) {
  return area.nativeSpatial ? area.nativeSpatial.view() : areaObjectsByX(session, area).map(object => object.id);
}
export function firstAreaSpatialIndex(session, area, x) {
  if (area.nativeSpatial) return area.nativeSpatial.firstByX(x);
  const index = areaObjectsByX(session, area).findIndex(object => f(object.position[0]) >= x);
  return index < 0 ? null : index;
}

export function nearestObjects(session, reference, nth, matches, excludeId = OBJECT_INVALID) {
  const area = session.registry.get(reference?.areaId);
  if (!area || !reference?.position) return OBJECT_INVALID;
  const objects = areaObjectsByX(session, area);
  let center = excludeId !== OBJECT_INVALID ? objects.findIndex(o => o.id === excludeId) : objects.findIndex(o => f(o.position[0]) >= f(reference.position[0]));
  if (center < 0) center = objects.length;
  const candidates = [];
  const visit = index => {
    const o = objects[index];
    if (o && o.id !== excludeId && matches(o)) candidates.push({ id: o.id, distance: nativeDistanceSquared(reference.position, o.position) });
  };
  if (excludeId === OBJECT_INVALID) visit(center);
  for (let offset = 1; offset <= objects.length; offset++) { visit(center + offset); visit(center - offset); }
  candidates.sort((a, b) => a.distance - b.distance);
  return candidates[Math.max(1, nth | 0) - 1]?.id ?? OBJECT_INVALID;
}

export function creatureCriteria(session, reference, criteria) {
  // The target keeps this flag for the entire search, including later candidates.
  let includeDead = false;
  return object => {
    if (object.objectType !== 5 || object.authored?.DM === 1 || object.isDM) return false;
    for (const [type, value] of criteria) {
      if (type === -1 || value === -1) continue;
      let matches;
      // Native checks the FIRST criterion value for RACIAL_TYPE_ALL, even here.
      if (type === 0) matches = criteria[0]?.[1] === 28 || (object.stats?.race ?? object.authored?.Race) === value;
      else if (type === 1) matches = Number(Boolean(object.isPC)) === value;
      else if (type === 2) matches = (object.stats?.classes ?? object.authored?.ClassList?.map(c => ({ id: c.Class })))?.some(c => c.id === value);
      else if (type === 4) { includeDead ||= value === 0; matches = includeDead ? session.isDead(object) || session.isDying(object) : !session.isDead(object) && !session.isDying(object); }
      else if (type === 5 || type === 6) {
        if (object.authored?.EffectList?.length) throw new Error('Saved spell effects require the effect import runtime');
        const found = (value | 0) !== -1 && (object.effects ?? []).some(e => e.spellId === value);
        matches = type === 5 ? found : !found;
      } else if (type === 7) {
        if (reference.objectType !== 5) return false;
        const flags = reference.perception?.get(object.id) ?? 0;
        const seen = Boolean(flags & 1), heard = Boolean(flags & 2);
        matches = [seen && heard, !seen && !heard, heard && !seen, seen && !heard, !heard, heard, !seen, seen][value];
      } else if (type === 3) {
        const reputation = session.reputation(object, reference);
        matches = value === 0 ? reputation >= 90 : value === 1 ? reputation <= 10 : value === 2 && reputation > 10 && reputation < 90;
      } else matches = false;
      if (!matches) return false;
    }
    return includeDead ? session.isDead(object) || session.isDying(object) : !session.isDead(object) && !session.isDying(object);
  };
}

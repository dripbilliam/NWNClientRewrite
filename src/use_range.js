import { OBJECT_INVALID } from './game_object_array.js';

const f = Math.fround;
const integer = (v, name) => { if (!Number.isInteger(v)) throw new Error(`Native use-range ${name} is unavailable`); return v | 0; };
const point = p => {
  if (!Array.isArray(p) || p.length !== 3 || !p.every(Number.isFinite)) throw new Error('Native use-range point is unavailable');
  return p.map(f);
};
const provider = (p, name) => { if (typeof p[name] !== 'function') throw new Error(`Native use-range provider ${name} is unavailable`); return p[name]; };
const range = (actor, offset) => {
  const value = actor.nativePathInfo?.[offset];
  if (!Number.isFinite(value)) throw new Error(`Native use-range path ${offset} is unavailable`);
  return f(value);
};

// GetUseRange140396480..14039672b. Output references preserve native partial
// writes: base radius is set even for a missing target; point is untouched.
export async function getUseRange(actor, id, out, p) {
  const gameObject = await p.object(id);
  out.range = range(actor, 'field4');
  const target = gameObject && await p.asObject(gameObject);
  if (!target || !await p.area(target)) return 0;
  switch (gameObject.objectType) {
    case 5:
      out.range = range(actor, 'field8'); out.point = point(target.position);
      out.range = f(range(target, 'field8') + out.range);
      integer(target.chairId, 'chair ID');
      out.range = f(out.range + f((target.chairId >>> 0) !== OBJECT_INVALID ? 0.8 : 0.3));
      return 1;
    case 7:
      if (integer(await provider(p, 'transition')(target), 'transition flag') !== 0) { out.point = point(target.position); return 1; }
      out.point = point(await provider(p, 'triggerPoint')(target, point(actor.position))); break;
    case 9:
      out.point = point(await provider(p, 'placeablePoint')(target, point(actor.position))); break;
    case 10:
      out.point = point(await provider(p, 'doorPoint')(target, point(actor.position), 0));
      out.point[1] = f(await provider(p, 'height')(await p.area(target), out.point.slice()));
      if (!Number.isFinite(out.point[1])) throw new Error('Native use-range door height is unavailable');
      out.range = f(out.range + f(0.75)); return 1;
    default: out.point = point(target.position); return 1;
  }
  out.range = f(out.range + f(0.5)); return 1;
}

// GetIsInUseRange140391310. Area transition containment bypasses LOS/range;
// ordinary targets use horizontal <= with raised LOS and native +.1 allowance.
export async function isInUseRange(actor, id, extra, transparent, p) {
  const gameObject = await p.object(id), target = gameObject && await p.asObject(gameObject);
  const area = target && await p.area(target);
  if (!target || !area || (actor.areaId >>> 0) !== (target.areaId >>> 0)) return 0;
  const allowance = f(f(extra) + f(0.1));
  if (!Number.isFinite(allowance)) throw new Error('Native use-range allowance is unavailable');
  if (gameObject.objectType === 7 && integer(await provider(p, 'transition')(target), 'transition flag') !== 0)
    return integer(await provider(p, 'inTrigger')(target, point(actor.position)), 'trigger containment');
  const out = { point: [0, 0, 0], range: 0 };
  await getUseRange(actor, id, out, p); // Native deliberately ignores return value.
  const from = point(actor.position), to = out.point.slice();
  from[1] = f(from[1] + 1); to[1] = f(to[1] + 1);
  if (integer(await p.lineOfSight(await p.area(target), from, to, actor.id, id, transparent), 'LOS result') === 0) return 0;
  out.range = f(out.range + allowance);
  const dy = f(out.point[2] - from[2]), dx = f(out.point[0] - from[0]);
  return Number(f(f(dy * dy) + f(dx * dx)) <= f(out.range * out.range));
}

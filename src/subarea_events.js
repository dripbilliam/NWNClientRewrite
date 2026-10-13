import { OBJECT_INVALID } from './game_object_array.js';

const required = (p, name) => {
  if (typeof p[name] !== 'function') throw new Error(`Native subarea event provider ${name} is unavailable`);
  return p[name];
};
const objectId = payload => (payload.objectIds?.[0] ?? OBJECT_INVALID) >>> 0;

// Script AI event10. Trigger140500ee6..140500f7d and
// encounter14043bf65..14043c093. The payload's WORD code is distinct from
// the AI event ID. Last-entering/exiting changes at dispatch, before scripts.
export async function dispatchSubareaEvent(target, eventId, payload, p) {
  if (eventId !== 10) return;
  const code = payload.scriptEvent & 65535;
  if (![12, 13].includes(code)) throw new Error(`Native subarea script event ${code} is not implemented`);
  if (![7, 13].includes(target.objectType)) throw new Error(`Native subarea event object type ${target.objectType} is not implemented`);
  const id = objectId(payload), entering = code === 12;
  target.eventObjects ??= {};
  target.eventObjects[entering ? 'entering' : 'exiting'] = id;
  if (target.objectType === 7) {
    if ((target.authored?.TrapFlag ?? 0) !== 0) {
      if (entering) { await required(p, 'enterTrap')(target, payload.integers?.[0] ?? 0); return; }
      if (await required(p, 'canFireTrap')(target, id, 0) === 0) return;
    }
    await required(p, 'runScript')(target, entering ? 1 : 2);
  } else {
    if (entering) {
      const before = await required(p, 'encounterEnterBeforeSpawn')();
      if (before !== 0) await required(p, 'runScript')(target, 0);
      await required(p, 'activateEncounter')(target, id, 0);
      if (before === 0) await required(p, 'runScript')(target, 0);
    } else {
      await required(p, 'removeEncounterCreatures')(target, OBJECT_INVALID);
      await required(p, 'runScript')(target, 1);
    }
  }
}

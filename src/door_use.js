import { setDoorState } from './door.js';

export function doorUsePoints(door) {
  const points = [...(door.actionPoints?.[door.animationState] ?? []), ...(door.animationState ? door.actionPoints?.[0] ?? [] : [])];
  return points.length ? points : [door.position];
}

// NWN picks opening side from the dot product with the door's facing vector.
export function doorOpeningSide(door, position) {
  const facing = door.facing ?? [-Math.sin(door.bearing ?? 0), 0, -Math.cos(door.bearing ?? 0)];
  return (position[0] - door.position[0]) * facing[0] + (position[2] - door.position[2]) * facing[2] > 0 ? 1 : 2;
}

export function createDoorUseHandler({ radius = 0.22 } = {}) {
  return {
    actions: ['open', 'close', 'transition'],
    intent: door => door.animationState === 0 ? 'open' : door.linkedTo || door.linkedToModule ? 'transition' : 'close',
    prepare(door) {
      if (door.animating) return { ok: false, message: 'Door is still moving' };
      if (door.animationState === 3 || door.usable === false) return { ok: false, message: 'That door cannot be used' };
      // Target adds 0.75 to use range and 0.1 tolerance; capsule radius stands in
      // for the as-yet-unmapped actor use-range field.
      return { ok: true, points: doorUsePoints(door), range: radius + 0.75 + 0.1 };
    },
    execute(door, actor, intent) {
      if (door.animating || door.animationState === 3 || door.usable === false) return { ok: false, message: 'That door cannot be used now' };
      if (intent === 'transition') {
        if (door.animationState === 0 || !(door.linkedTo || door.linkedToModule)) return { ok: false, message: 'That door is no longer an open area transition' };
        return { ok: true, message: 'Running door transition script', events: [{ type: 'door.clicked', script: door.scripts?.click ?? '' }] };
      }
      if (!['open', 'close'].includes(intent)) return { ok: false, message: 'Unknown door action' };
      // Hold captured intent so repeated clicks cannot silently toggle twice.
      if ((intent === 'open') === (door.animationState !== 0)) return { ok: true, message: `Door is already ${intent === 'open' ? 'open' : 'closed'}` };
      if (intent === 'open' && door.locked) {
        door.lastFailedToOpenBy = actor.id;
        return { ok: false, message: 'Door is locked', events: [{ type: 'door.failedToOpen', script: door.scripts?.failToOpen ?? '' }] };
      }
      const next = intent === 'open' ? doorOpeningSide(door, actor.position) : 0;
      const previousState = door.animationState;
      const result = setDoorState(door, next, actor.position, radius);
      if (!result.changed) return { ok: false, message: result.message };
      door.version = (door.version ?? 0) + 1;
      door.lastUsedBy = actor.id;
      return { ok: true, message: result.message, events: [{ type: 'door.stateChanged', previousState, state: next, script: door.scripts?.[next ? 'open' : 'closed'] ?? '' }] };
    },
    settled: door => !door.animating
  };
}

import { runtimeDiagnostics } from './runtime_diagnostics.js';
// Generic approach/use/settle lifecycle. Handlers supply object-specific rules.
const scriptActionIds = { open: 5, close: 6, talk: 7, use: 15, transition: 15 };
export class ActionQueue {
  constructor({ registry, actor, handlers, navigate, move, inRange, face = () => {}, onStatus = () => {}, onEvent = () => {} }) {
    Object.assign(this, { registry, actor, handlers, navigate, move, inRange, face, onStatus, onEvent });
    this.current = null;
    this.history = [];
  }
  use(targetId) { return this.request(targetId); }
  request(targetId, requestedIntent = null) {
    const target = this.registry.get(targetId), handler = this.handlers[target?.kind];
    if (!target || !handler) {
      this.cancel('Replaced by another selection');
      this.onStatus('That object does not have a use action yet');
      runtimeDiagnostics.record('interaction.unavailable', 'That object does not have a use action yet', { actorId: this.actor.id, targetId, kind: target?.kind });
      return false;
    }
    const intent = requestedIntent ?? handler.intent(target);
    if (requestedIntent !== null && !handler.actions?.includes(intent)) {
      this.onStatus('That action is not available for this object');
      runtimeDiagnostics.record('interaction.unavailable', 'That action is not available for this object', { actorId: this.actor.id, targetId, intent });
      return false;
    }
    if (this.current?.targetId === targetId && (this.current.intent === intent || this.current.phase === 'settling')) return false;
    this.cancel('Replaced by another action');
    this.current = { targetId, intent, phase: 'queued', route: [], waypoint: 0 };
    this.actor.currentActionId = scriptActionIds[intent] ?? 65535;
    this.onStatus(`${intent} ${target.tag || target.kind} queued`);
    return true;
  }
  cancel(message = 'Action cancelled') { if (this.current) this.finish('cancelled', message); }
  finish(phase, message) {
    if (phase === 'failed') runtimeDiagnostics.record('interaction.failed', message, { actorId: this.actor.id, targetId: this.current.targetId, intent: this.current.intent, areaId: this.actor.areaId });
    this.current.phase = phase;
    this.current.message = message;
    this.history.push(this.current);
    if (this.history.length > 32) this.history.shift();
    this.current = null;
    this.actor.currentActionId = 65535;
    this.onStatus(message);
  }
  update(delta) {
    const action = this.current;
    if (!action || !Number.isFinite(delta) || delta < 0) return;
    const target = this.registry.get(action.targetId), handler = this.handlers[target?.kind];
    if (!target || target.areaId !== this.actor.areaId || !handler) { this.finish('failed', 'Target is no longer in this area'); return; }
    if (action.phase === 'settling') {
      if (handler.settled(target)) this.finish('complete', action.result.message);
      return;
    }
    if (action.phase === 'queued') {
      const prepared = handler.prepare(target, this.actor, action.intent);
      if (!prepared.ok) { this.finish('failed', prepared.message); return; }
      action.points = prepared.points; action.range = prepared.range;
      if (!this.inRange(target, action.points, action.range)) {
        const route = this.navigate(action.points, action.range);
        if (!route) { this.finish('failed', 'No walkable route to that object'); return; }
        action.route = route;
        action.phase = 'approaching';
        this.actor.currentActionId = 0;
        this.onStatus(`Approaching ${target.tag || target.kind}`);
      }
    }
    if (action.phase === 'approaching') {
      if (!this.inRange(target, action.points, action.range)) {
        const waypoint = action.route[action.waypoint];
        if (!waypoint) { this.finish('failed', 'Object is not in use range'); return; }
        const moved = this.move(waypoint, delta);
        if (moved === 'blocked') { this.finish('failed', 'The route is blocked'); return; }
        if (moved === 'arrived') action.waypoint++;
        return;
      }
    }
    // Recheck object rules after approaching: state may have changed meanwhile.
    this.face(target.position);
    this.actor.currentActionId = scriptActionIds[action.intent] ?? 65535;
    const result = handler.execute(target, this.actor, action.intent);
    action.result = result;
    for (const event of result.events ?? []) this.onEvent({ ...event, targetId: target.id });
    if (!result.ok) { this.finish('failed', result.message); return; }
    if (handler.settled(target)) this.finish('complete', result.message);
    else { action.phase = 'settling'; this.onStatus(result.message); }
  }
}

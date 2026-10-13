// Native AddEventAbsoluteTime inserts BEFORE only strictly later timestamps:
// equal timestamps retain insertion order. AssignCommand is a zero-delay event.
export class ScriptScheduler {
  constructor({ validTarget, dispatch, beforePump = () => {}, onError = () => {}, maxEventsPerPump = 256 }) {
    Object.assign(this, { validTarget, dispatch, beforePump, onError, maxEventsPerPump });
    this.time = 0; this.sequence = 0; this.events = []; this.pumping = false;
  }
  enqueue(targetId, event, seconds = 0) {
    if (!Number.isFinite(seconds)) throw new Error('Invalid event delay');
    const milliseconds = Math.trunc(Math.fround(Math.max(0, seconds) * 1000));
    return this.enqueueMilliseconds(targetId, event, milliseconds);
  }
  // Combat AI delays are already uint32 milliseconds. Avoid a lossy
  // milliseconds -> float seconds -> milliseconds conversion.
  enqueueMilliseconds(targetId, event, milliseconds) {
    if (!Number.isSafeInteger(milliseconds) || milliseconds < 0) throw new Error('Invalid event millisecond delay');
    const queued = { targetId, event, due: this.time + milliseconds, sequence: this.sequence++ };
    const index = this.events.findIndex(e => e.due > queued.due);
    if (index < 0) this.events.push(queued); else this.events.splice(index, 0, queued);
    return queued;
  }
  advance(milliseconds) { if (Number.isFinite(milliseconds) && milliseconds >= 0) this.time += milliseconds; }
  async pump() {
    if (this.pumping) return;
    this.pumping = true;
    try {
      // Expiry can execute direct lifecycle scripts. Serialize it with event
      // dispatch so a second render frame cannot interleave another script.
      await this.beforePump();
      let count = 0;
      while (this.events[0]?.due <= this.time && count++ < this.maxEventsPerPump) {
        const queued = this.events.shift();
        if (!this.validTarget(queued.targetId)) continue;
        try { await this.dispatch(queued); } catch (error) { this.onError(error, queued); }
      }
      // Leave overflow queued for the next pump; never silently discard it.
    } finally { this.pumping = false; }
  }
}

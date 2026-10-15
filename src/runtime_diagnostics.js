// A diagnostic is an observed occurrence, not a claim that unreachable code ran.
// Keep the complete journal separate from short HUD/console message buffers.
export function diagnosticJson(value) {
  const seen = new WeakSet();
  return JSON.stringify(value, (_key, item) => {
    if (typeof item === 'bigint') return item.toString();
    if (item instanceof Error) return { name: item.name, message: item.message, stack: item.stack };
    if (item instanceof ArrayBuffer || ArrayBuffer.isView(item)) return { binaryBytes: item.byteLength };
    if (typeof item === 'object' && item !== null) { if (seen.has(item)) return '[circular]'; seen.add(item); }
    return item;
  });
}
function sessionId() {
  if (globalThis.crypto && typeof globalThis.crypto.randomUUID === 'function') return globalThis.crypto.randomUUID();
  return `run-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}
export class RuntimeDiagnostics {
  constructor({ session = sessionId(), context = () => ({}), sink = null, now = () => Date.now() } = {}) {
    Object.assign(this, { session, context, sink, now });
    this.records = []; this.pending = []; this.listeners = new Set(); this.errors = new WeakMap();
    this.writing = null; this.storageError = null; this.location = 'Memory · persistence not attached';
    this.repeated = new Map();
  }
  subscribe(listener) { this.listeners.add(listener); listener(this); return () => this.listeners.delete(listener); }
  publish() { for (const listener of this.listeners) listener(this); }
  record(code, message, context = {}, severity = 'warning') {
    const record = { version: 1, session: this.session, sequence: this.records.length + 1,
      timestamp: new Date().toISOString(), code, severity, message: String(message), context: { ...this.context(), ...context } };
    // Copy metadata at occurrence time. Never retain live objects/asset bytes.
    const snapshot = JSON.parse(diagnosticJson(record));
    this.records.push(snapshot); this.pending.push(snapshot); this.publish();
    if (this.sink && !this.storageError) void this.flush({ repeated: false }).catch(() => {});
    return snapshot;
  }
  // Only explicitly identified polling omissions use aggregation. Script calls,
  // resource failures and ordinary records remain separate occurrences.
  repeat(code, message, context = {}, severity = 'warning') {
    const detail = { ...this.context(), ...context }, key = diagnosticJson([code, message, detail, severity]);
    const timestamp = new Date(this.now()).toISOString();
    let entry = this.repeated.get(key);
    if (!entry) {
      entry = { code, message, context: JSON.parse(diagnosticJson(detail)), severity, total: 1, pending: 0, first: timestamp, last: timestamp };
      this.repeated.set(key, entry);
      return this.record(code, message, { ...detail, occurrences: 1, totalOccurrences: 1, firstOccurrence: timestamp, lastOccurrence: timestamp }, severity);
    }
    entry.total++; entry.pending++; entry.last = timestamp;
  }
  flushRepeated() {
    for (const entry of this.repeated.values()) {
      if (!entry.pending) continue;
      const count = entry.pending; entry.pending = 0;
      this.record(entry.code, entry.message, { ...entry.context, occurrences: count, totalOccurrences: entry.total,
        firstOccurrence: entry.first, lastOccurrence: entry.last }, entry.severity);
    }
  }
  error(error, code = 'runtime.failure', context = {}) {
    const detail = { ...error?.diagnosticContext, ...context };
    code = error?.diagnosticCode ?? code;
    if (error && typeof error === 'object') {
      const recorded = this.errors.get(error);
      if (recorded?.has(code)) return recorded.get(code);
      const record = this.record(code, error.message ?? String(error), { ...detail, stack: error.stack }, code === 'resource.lookup-failed' ? 'info' : 'error');
      const entries = recorded ?? new Map(); entries.set(code, record); this.errors.set(error, entries); return record;
    }
    return this.record(code, String(error), detail);
  }
  attach(sink, location) { this.sink = sink; this.location = location; this.storageError = null; this.publish(); return this.flush(); }
  async flush({ repeated = true } = {}) {
    if (repeated) this.flushRepeated();
    if (this.writing) { await this.writing; if (this.pending.length) return this.flush({ repeated: false }); return; }
    if (!this.sink) return;
    this.writing = (async () => {
      while (this.pending.length) {
        const batch = this.pending.slice(0, 200);
        try { await this.sink(batch); this.pending.splice(0, batch.length); this.storageError = null; }
        catch (error) {
          const message = error.message ?? String(error), firstFailure = this.storageError !== message;
          this.storageError = message;
          if (firstFailure) this.record('diagnostic.save-failed', message, { location: this.location }, 'error');
          throw error;
        }
        finally { this.publish(); }
      }
    })();
    try { await this.writing; } finally { this.writing = null; }
  }
  jsonl() { this.flushRepeated(); return this.records.map(record => JSON.stringify(record)).join('\n') + (this.records.length ? '\n' : ''); }
}

export const runtimeDiagnostics = new RuntimeDiagnostics();

// A Set compatible adapter also records swallowed UI asset failures.
export class DiagnosticWarnings extends Set {
  constructor(context) { super(); this.context = context; }
  add(message) { runtimeDiagnostics.record('ui.asset-unavailable', message, this.context?.() ?? {}); return super.add(message); }
}

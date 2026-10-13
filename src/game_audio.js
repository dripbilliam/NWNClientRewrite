import { RESOURCE_TYPE } from './resource_archive.js';
import { decodeImaWav } from './ima_adpcm.js';
import { runtimeDiagnostics } from './runtime_diagnostics.js';

// Installed resources remain in memory. Browser decoding/output is an adapter;
// native script routing and recipient distance live in ModuleSession.
export class GameAudio {
  constructor(resolver, { getObject, getPlayer, onState = () => {}, onDiagnostic = () => {}, createContext = () => new AudioContext() }) {
    Object.assign(this, { resolver, getObject, getPlayer, onState, onDiagnostic, createContext });
    this.context = null; this.cache = new Map(); this.pending = []; this.active = new Set(); this.disposed = false;
    this.state = { decoded: 0, played: 0, pending: 0, context: 'uninitialized', last: null };
  }
  publish() {
    this.state.context = this.context?.state ?? 'uninitialized'; this.state.pending = this.pending.length;
    this.onState({ ...this.state });
  }
  ensureContext() {
    if (!this.context) {
      this.context = this.createContext();
      this.context.addEventListener('statechange', () => { if (!this.disposed) { this.flush(); this.publish(); } });
    }
    return this.context;
  }
  async unlock() {
    if (this.disposed || !this.context) return;
    try { await this.context.resume(); this.flush(); this.publish(); }
    catch (error) { runtimeDiagnostics.error(error, 'audio.output-failed'); this.onDiagnostic(`Audio output: ${error.message}`); }
  }
  async play(event) {
    if (this.disposed) return;
    const resRef = String(event.resRef).toLowerCase();
    try {
      const context = this.ensureContext();
      if (!this.cache.has(resRef)) this.cache.set(resRef, this.resolver.getResource(resRef, RESOURCE_TYPE.WAV).then(bytes => {
        const ima = decodeImaWav(bytes);
        if (!ima) return context.decodeAudioData(bytes.slice(0));
        const decoded = context.createBuffer(ima.channels, ima.frames, ima.sampleRate);
        ima.samples.forEach((samples, c) => decoded.copyToChannel(samples, c));
        return decoded;
      }));
      const buffer = await this.cache.get(resRef);
      if (this.disposed) return;
      this.state.decoded++; this.state.last = { resRef, objectId: event.objectId, channels: buffer.numberOfChannels, sampleRate: buffer.sampleRate, duration: buffer.duration };
      if (context.state === 'running') this.start(event, buffer);
      else {
        // Input resumes output. Never await a user gesture in the script pump.
        if (this.pending.length >= 64) throw new Error('Too many sound cues awaiting audio input permission');
        this.pending.push({ event, buffer });
      }
      this.publish();
    } catch (error) {
      runtimeDiagnostics.error(error, 'audio.sound-failed', { resRef, objectId: event.objectId, module: this.resolver.moduleName });
      if (!this.disposed) this.onDiagnostic(`Sound ${resRef}: ${error.message}`);
    }
  }
  start(event, buffer) {
    const source = this.context.createBufferSource(); source.buffer = buffer;
    const record = { source, objectId: event.objectId, position: event.position };
    // Own-player cues are centered. Non-player spatial attenuation is currently
    // a browser approximation, pending the native client's audio listener map.
    if (event.objectId !== this.getPlayer()?.id && buffer.numberOfChannels === 1) {
      record.panner = this.context.createPanner();
      Object.assign(record.panner, { panningModel: 'equalpower', distanceModel: 'linear', refDistance: 1, maxDistance: 20, rolloffFactor: 1 });
      source.connect(record.panner); record.panner.connect(this.context.destination);
    } else source.connect(this.context.destination);
    this.active.add(record); this.update();
    source.addEventListener('ended', () => { this.active.delete(record); source.disconnect(); record.panner?.disconnect(); });
    source.start(); this.state.played++;
  }
  flush() {
    if (this.disposed || this.context?.state !== 'running') return;
    for (const { event, buffer } of this.pending.splice(0)) this.start(event, buffer);
  }
  update() {
    if (!this.context || this.disposed) return;
    const player = this.getPlayer();
    if (player?.position) this.setPosition(this.context.listener, player.position);
    for (const record of this.active) if (record.panner) this.setPosition(record.panner, this.getObject(record.objectId)?.position ?? record.position);
  }
  setPosition(node, p) { node.positionX.value = p[0]; node.positionY.value = p[1]; node.positionZ.value = p[2]; }
  dispose() {
    this.disposed = true; this.pending = [];
    for (const { source, panner } of this.active) { source.stop(); source.disconnect(); panner?.disconnect(); }
    this.active.clear(); this.cache.clear();
    if (this.context) void this.context.close().catch(() => {});
  }
}

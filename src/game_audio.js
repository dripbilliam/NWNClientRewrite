import { RESOURCE_TYPE } from './resource_archive.js';
import { decodeImaWav } from './ima_adpcm.js';
import { runtimeDiagnostics } from './runtime_diagnostics.js';
import {nativeWaveTiming} from './native_wave_timing.js';
import {NativeEffectSound} from './native_effect_sound.js';
import {nativeBmuWave} from './native_bmu_wave.js';
import {NativeDelayedSounds} from './native_delayed_sound.js';

// Installed resources remain in memory. Browser decoding/output is an adapter;
// Script/server owners choose recipients. Native source profiles are opt-in;
// existing singleplayer cues retain their separate browser approximation.
export class GameAudio {
  constructor(resolver, { getObject, getPlayer, getListener = null, onState = () => {}, onDiagnostic = () => {}, createContext = () => new AudioContext(),milliseconds=()=>Math.trunc(performance.now())>>>0 }) {
    Object.assign(this, { resolver, getObject, getPlayer, getListener, onState, onDiagnostic, createContext });
    this.context = null; this.cache = new Map(); this.pending = []; this.active = new Set(); this.disposed = false;this.generations=new Map();this.streams=new Set();this.bufferTimings=new WeakMap();
    this.state = { decoded: 0, played: 0, pending: 0, context: 'uninitialized', last: null };
    this.delayed=new NativeDelayedSounds({now:milliseconds,play:event=>{void this.play(event);}});
  }
  publish() {
    this.state.context = this.context?.state ?? 'uninitialized'; this.state.pending = this.pending.length;
    this.state.delayed=this.delayed.queue.length;
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
    if (this.disposed) return;
    try { await this.ensureContext().resume();for(const stream of this.streams)stream.flush(true); this.flush(); this.publish(); }
    catch (error) { runtimeDiagnostics.error(error, 'audio.output-failed'); this.onDiagnostic(`Audio output: ${error.message}`); }
  }
  loadBuffer(resRef){
    resRef=String(resRef).toLowerCase();const context=this.ensureContext();
    if(!this.cache.has(resRef))this.cache.set(resRef,this.resolver.getResource(resRef,RESOURCE_TYPE.WAV).then(async bytes=>{
      const bmu=nativeBmuWave(bytes),timing=bmu?.timing??nativeWaveTiming(bytes),ima=bmu?null:decodeImaWav(bytes);let buffer;if(!ima)buffer=await context.decodeAudioData(bmu?.payload??bytes.slice(0));
      else{buffer=context.createBuffer(ima.channels,ima.frames,ima.sampleRate);ima.samples.forEach((samples,c)=>buffer.copyToChannel(samples,c));}this.bufferTimings.set(buffer,timing);return buffer;
    }));return this.cache.get(resRef);
  }
  bufferTiming(buffer){return this.bufferTimings.get(buffer)??null;}
  effectSound(options){
    if(this.disposed)throw new Error('Audio output is disposed');
    if(options.resRef&&!this.reportedEffectMixer){this.reportedEffectMixer=true;runtimeDiagnostics.record('audio.effect-mixer-unimplemented','Native effect priority voice limits, synchronized pause and range-resume sample phase are not connected',{});}
    return new NativeEffectSound(this,{...options,onFailure:(error,data)=>{
      runtimeDiagnostics.error(error,'audio.effect-sound-failed',{...data,channel:options.channel,module:this.resolver.moduleName});
      this.onDiagnostic(`Sound ${data.resRef}: ${error.message}`);
    }});
  }
  effectSounds(){return [...this.streams].filter(s=>s instanceof NativeEffectSound).map(s=>s.snapshot());}
  clearResourceCache(){this.cache.clear();}
  delayedSounds(){return this.delayed.snapshot();}
  async play(event) {
    if (this.disposed||event.current&&!event.current()) return;
    if(event.nativeSource?.delay){this.ensureContext();this.delayed.add({...event,position:event.position?[...event.position]:event.position,nativeSource:{...event.nativeSource,delay:0}},event.nativeSource.delay);this.publish();return;}
    const owner=event.replace?`${event.objectId}:${event.channel??''}`:null,generation=owner?(this.generations.get(owner)??0)+1:0;
    if(owner)this.generations.set(owner,generation);
    const resRef = String(event.resRef).toLowerCase();
    try {
      const context = this.ensureContext();
      const buffer = await this.loadBuffer(resRef);
      if (this.disposed||event.current&&!event.current()||owner&&this.generations.get(owner)!==generation||event.channel==='voice'&&!this.getObject(event.objectId)) return;
      if(event.nativeSource?.monoOnly&&buffer.numberOfChannels!==1)return;
      if(owner){
        this.pending=this.pending.filter(cue=>cue.event.objectId!==event.objectId||cue.event.channel!==event.channel);
        for(const record of [...this.active])if(record.objectId===event.objectId&&record.channel===event.channel){record.source.stop();this.active.delete(record);}
      }
      this.state.decoded++; this.state.last = { resRef, objectId: event.objectId, channel:event.channel,channels: buffer.numberOfChannels, sampleRate: buffer.sampleRate, duration: buffer.duration };
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
    const native=event.nativeSource;
    if(native){
      this.update();
      if(native.positional){
        const listener=this.listenerState;if(!listener)return;
        const f=Math.fround,d=event.position.map((v,i)=>f(listener.position[i]-v));
        if(f(Math.sqrt(f(f(f(d[0]*d[0])+f(d[1]*d[1]))+f(d[2]*d[2]))))>native.maxDistance)return;
      }
    }
    const source = this.context.createBufferSource(); source.buffer = buffer;
    const record = { source, objectId: event.objectId, position: event.position,channel:event.channel,fixedPosition:Boolean(native?.fixedPosition) };
    if(native){
      record.gain=this.context.createGain();record.gain.gain.value=Math.fround(native.volume/(native.positional?255:127));source.connect(record.gain);
      if(native.positional){record.panner=this.context.createPanner();Object.assign(record.panner,{panningModel:'equalpower',distanceModel:'linear',refDistance:native.referenceDistance,maxDistance:native.maxDistance,rolloffFactor:native.rolloff});record.gain.connect(record.panner);record.panner.connect(this.context.destination);}
      else record.gain.connect(this.context.destination);
    }
    // Legacy own-player cues are centered; native profiles above explicitly
    // retain positional self-cues and their own listener/source defaults.
    else if (event.channel!=='gui' && event.objectId !== this.getPlayer()?.id && buffer.numberOfChannels === 1) {
      record.panner = this.context.createPanner();
      Object.assign(record.panner, { panningModel: 'equalpower', distanceModel: 'linear', refDistance: 1, maxDistance: 20, rolloffFactor: 1 });
      source.connect(record.panner); record.panner.connect(this.context.destination);
    } else source.connect(this.context.destination);
    this.active.add(record); this.update();
    source.addEventListener('ended', () => { this.active.delete(record); source.disconnect(); record.gain?.disconnect();record.panner?.disconnect(); });
    source.start(); this.state.played++;
  }
  flush() {
    if (this.disposed || this.context?.state !== 'running') return;
    for(const stream of this.streams)stream.flush();
    for (const { event, buffer } of this.pending.splice(0))if((!event.current||event.current())&&(event.channel!=='voice'||this.getObject(event.objectId)))this.start(event, buffer);
  }
  update() {
    if (!this.context || this.disposed) return;
    this.delayed.update();this.state.delayed=this.delayed.queue.length;
    const player = this.getPlayer();
    if(this.getListener){const listener=this.getListener();if(listener){this.listenerState=listener;this.setPosition(this.context.listener,listener.position);for(const [prefix,vector]of [['forward',listener.forward],['up',listener.up]])for(let i=0;i<3;i++)this.context.listener[prefix+'XYZ'[i]].value=vector[i];}}
    else if (player?.position) this.setPosition(this.context.listener, player.position);
    for(const stream of this.streams)stream.update();
    for (const record of [...this.active]){
      const object=this.getObject(record.objectId);
      if(record.channel==='voice'&&!object){record.source.stop();this.active.delete(record);continue;}
      if(record.panner)this.setPosition(record.panner,record.fixedPosition?record.position:object?.position??record.position);
    }
  }
  setPosition(node, p) { node.positionX.value = p[0]; node.positionY.value = p[1]; node.positionZ.value = p[2]; }
  dispose() {
    this.disposed = true; this.pending = [];
    this.delayed.clear();
    for(const stream of [...this.streams])stream.dispose();
    for (const { source, panner,gain } of this.active) { source.stop(); source.disconnect();gain?.disconnect(); panner?.disconnect(); }
    this.active.clear(); this.cache.clear();this.generations.clear();
    if (this.context) void this.context.close().catch(() => {});
  }
}

import { intEntry } from './combat_stats.js';
import { nativeFloatEntry } from './movement_rate.js';
import { spellStringEntry } from './spell_metadata.js';
import {selectVisualEffects,detachCompetingVisual} from './visual_selection.js';

// Client loader14096cf10 selects duration+d2; procedural model selection
//14096c8e0 Type4 reads Param7. Type4 owner14096a570 reads Param1..6 with
// unconditional2DA output writes, even when the entry query returns false.
export function durationVisualProgram(visualId, visuals, programs) {
  const entry = intEntry(visuals, visualId & 65535, 'ProgFX_Duration');
  if (!entry.found) return null;
  const id = entry.value & 65535, type = intEntry(programs, id, 'Type').value & 255;
  if (type !== 4) return { id, type };
  return { id, type, model: spellStringEntry(programs, id, 'Param7'),
    animation: spellStringEntry(programs, id, 'Param1'), speed: nativeFloatEntry(programs, id, 'Param2').value,
    shadows: intEntry(programs, id, 'Param3').value !== 0,
    field10c: intEntry(programs, id, 'Param4').value & 255,
    field110: intEntry(programs, id, 'Param5').value,
    vision: intEntry(programs, id, 'Param6').value !== 0 };
}

// Local rendering reconciliation, deliberately separate from canonical effect
// records and their native duplicate/last-match removal semantics. An instance
// owns its asynchronous load and resources; late loads cannot reattach after
// removal, destruction, rebinding or area transfer.
export class LoopingVisualPresentation {
  constructor({ objects, object, render, tables, create, createNative, report, areaId,selectedObjectId1406ac1c0,viewGate1407dadb0 }) {
    Object.assign(this, { objects, object, render, tables, create, createNative, report, areaId,selectedObjectId1406ac1c0,viewGate1407dadb0 });
    this.entries = new Map(); this.retiring = new Set(); this.released = new WeakSet(); this.closed = false; this.failures = new Set();this.nextOrder=0;
  }
  failure(code, message, data) {
    const key = `${code}:${JSON.stringify(data)}`;
    if (!this.failures.has(key)) { this.failures.add(key); this.report(code, message, data); }
  }
  valid(entry) {
    return this.bound(entry) && !entry.removed &&
      (entry.transient || entry.actor.nativeLoopingVisuals160?.records.includes(entry.record));
  }
  bound(entry) { return !this.closed && this.object(entry.actor.id) === entry.actor && this.render(entry.actor.id) === entry.render && entry.actor.areaId === entry.areaId; }
  addTransient(actor,record){
    const render=this.render(actor.id);
    if(this.closed||this.object(actor.id)!==actor||!render||this.areaId!==undefined&&actor.areaId!==this.areaId)return 0;
    // This identity belongs to the client presentation list, never the server's
    // canonical looping array or the shared game-object allocator.
    record=structuredClone(record);
    const entry={actor,render,areaId:actor.areaId,record,transient:true,instance:null,removed:false,order:this.nextOrder++};
    this.entries.set(record,entry);entry.ready=this.load(entry);return 1;
  }
  update(delta) {
    if (this.closed) return;
    const retained = new Set();
    for (const actor of this.objects()) {
      if (this.object(actor.id) !== actor || this.areaId!==undefined&&actor.areaId!==this.areaId) continue;
      const render = this.render(actor.id); if (!render) continue;
      for (const record of actor.nativeLoopingVisuals160?.records ?? []) {
        retained.add(record);
        const old = this.entries.get(record);
        if (old && old.actor === actor && old.render === render) continue;
        if (old) this.remove(old);
        const entry = { actor, render, areaId:actor.areaId, record, instance: null, removed: false,order:this.nextOrder++ };
        this.entries.set(record, entry);
        entry.ready = this.load(entry);
      }
    }
    for (const [record, entry] of this.entries) {
      if ((!entry.transient&&!retained.has(record)) || !this.valid(entry)) { if(entry.transient)this.remove(entry);else this.retire(entry); this.entries.delete(record);this.selectInstances(entry.actor); }
      else if(entry.instance) {
        try {
          entry.instance.update(delta);
          this.selectInstances(entry.actor);
          if(entry.transient&&entry.instance?.isRetired()){
            // Render update140767240 removes naturally completed visuals;
            // it does not issue the server-loop removal's Stop(1).
            if(entry.instance.nativeState?.durationFc===0){this.detachCompeting(entry);this.selectInstances(entry.actor);}
            this.remove(entry);this.entries.delete(record);
          }
        }
        catch(error) { this.release(entry.instance,entry);entry.instance=null;if(entry.transient){entry.removed=true;this.entries.delete(record);}this.failure('visual.update-failed',error.message,{objectId:entry.actor.id,visualId:record.visualId,stack:error.stack}); }
      }
    }
    for(const entry of this.retiring){
      if(!this.bound(entry)){this.remove(entry);this.retiring.delete(entry);continue;}
      try{
        entry.instance.update(delta);this.selectInstances(entry.actor);
        if(!entry.instance){this.retiring.delete(entry);continue;}
        if(entry.instance.isRetired()){this.remove(entry);this.retiring.delete(entry);}
      }catch(error){this.remove(entry);this.retiring.delete(entry);this.failure('visual.retirement-failed',error.message,{objectId:entry.actor.id,visualId:entry.record.visualId,stack:error.stack});}
    }
  }
  async load(entry) {
    const data = { objectId: entry.actor.id, visualId: entry.record.visualId };
    try {
      const tables = await this.tables(),{ visuals, programs }=tables;
      if (!this.valid(entry)) return;
      if(this.createNative){
        const instance=await this.createNative(entry.actor,entry.render,entry.record,tables);
        if(!this.valid(entry)){this.release(instance,entry);return;}
        entry.instance=instance;instance.attach();this.selectInstances(entry.actor);return;
      }
      if(entry.transient)throw new Error('One-shot visuals require the full native visual loader');
      const program = durationVisualProgram(entry.record.visualId, visuals, programs);
      if (!program) { this.failure('visual.duration-nodes-unimplemented', 'Looping visual model nodes are not yet presented', data); return; }
      if (program.type !== 4) { this.failure('visual.program-unimplemented', 'Looping visual procedural type is not implemented', { ...data, programId: program.id, type: program.type }); return; }
      const instance = await this.create(entry.actor, entry.render, entry.record, program);
      if (!this.valid(entry)) { this.release(instance,entry); return; }
      entry.program = program; entry.instance = instance; instance.attach();this.selectInstances(entry.actor);
    } catch (error) {
      this.release(entry.instance,entry); entry.instance=null;
      if (this.valid(entry)) this.failure('visual.load-failed', error.message, { ...data, stack: error.stack });
    } finally {
      if(entry.transient&&!entry.instance){entry.removed=true;this.entries.delete(entry.record);}
    }
  }
  release(instance,entry){
    if(!instance||this.released.has(instance))return;this.released.add(instance);
    try{instance.dispose();}catch(error){this.failure('visual.dispose-failed',error.message,{objectId:entry.actor.id,visualId:entry.record.visualId,stack:error.stack});}
  }
  nativeEntries(actor){
    return [...new Set([...this.entries.values(),...this.retiring])].filter(entry=>entry.actor===actor&&this.bound(entry)&&entry.instance?.nativeState).sort((a,b)=>a.order-b.order);
  }
  // Local body replacement preserves the view wrapper. Re-resolve native
  // attachment owners against its NEW model without replaying impact/start or
  // replacing effect/model/phase identities. Detached losers stay detached.
  // Native renderer handle-invalidation/event propagation remains a diagnosed
  // platform boundary; this bridge does not claim to implement that service.
  rebindModel(actor){
    for(const entry of this.nativeEntries(actor)){
      if(!entry.instance.nativeState.attached114)continue;
      try{entry.instance.attachModels();}
      catch(error){this.release(entry.instance,entry);entry.instance=null;this.failure('visual.rebind-failed',error.message,{objectId:actor.id,visualId:entry.record.visualId,stack:error.stack});}
    }
  }
  selectInstances(actor){
    const entries=this.nativeEntries(actor).filter(entry=>this.valid(entry)||this.retiring.has(entry));
    if(!entries.length)return;
    const byState=new Map(entries.map(entry=>[entry.instance.nativeState,entry.instance]));
    const owner={id:actor.id,suppressed108:0,visuals80:[...byState.keys()]};
    const required=(name,...args)=>{if(typeof this[name]!=='function')throw new Error(`Native visual selection provider ${name} is unavailable`);return this[name](...args);};
    const p={programType:e=>e.programType10d&255,selectedObjectId1406ac1c0:()=>required('selectedObjectId1406ac1c0'),viewGate1407dadb0:()=>required('viewGate1407dadb0'),attach:e=>byState.get(e).attachModels(),detach:e=>byState.get(e).detachModels(),start:e=>byState.get(e).restart(),stop:(e,value)=>byState.get(e).stopForSelection(value)};
    // Preserve physical record order even when asynchronous resources resolve
    // in a different order. Native selection chooses the last equal priority.
    try{for(const type of new Set(owner.visuals80.map(e=>e.programType10d&255)))selectVisualEffects(owner,type,p);}
    catch(error){for(const entry of entries){this.release(entry.instance,entry);entry.instance=null;}this.failure('visual.selection-failed',error.message,{objectId:actor.id,stack:error.stack});}
  }
  // The instance owns the verified native cessation/retirement predicates.
  // Reconciliation never invents a timeout or keeps a stale area binding alive.
  detachCompeting(entry){
    if(!entry.instance?.nativeState)return;
    const entries=this.nativeEntries(entry.actor),byState=new Map(entries.map(e=>[e.instance.nativeState,e.instance]));
    detachCompetingVisual({visuals80:[...byState.keys()]},entry.instance.nativeState,{programType:e=>e.programType10d&255,detach:e=>byState.get(e).detachModels()});
  }
  retire(entry){
    entry.removed=true;
    if(!this.bound(entry)||!entry.instance?.stop){this.remove(entry);return;}
    try{
      if(typeof entry.instance.isRetired!=='function')throw new Error('Visual cessation has no retirement predicate');
      this.detachCompeting(entry);
      entry.instance.stop(1);this.retiring.add(entry);
    }catch(error){this.remove(entry);this.failure('visual.stop-failed',error.message,{objectId:entry.actor.id,visualId:entry.record.visualId,stack:error.stack});}
  }
  remove(entry) { entry.removed = true; this.release(entry.instance,entry); entry.instance = null; }
  dispose() { this.closed = true; for (const entry of [...this.entries.values(),...this.retiring]) this.remove(entry); this.entries.clear();this.retiring.clear(); }
  snapshot() {
    return [...this.entries.values(),...this.retiring].map(entry => ({ objectId: entry.actor.id, visualId: entry.record.visualId,transient:Boolean(entry.transient),retiring:entry.removed,
      programId: (entry.instance?.program??entry.program)?.id, model: (entry.instance?.program??entry.program)?.model, animation: (entry.instance?.program??entry.program)?.animation,
      ready: Boolean(entry.instance),attached:entry.instance?.nativeState?Boolean(entry.instance.nativeState.attached114):undefined,scope:entry.instance?.nativeState?.scope10c,presentation: entry.instance?.snapshot?.() ?? null }));
  }
}

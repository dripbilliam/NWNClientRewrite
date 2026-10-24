import {createHash} from 'node:crypto';
import {parseModel} from '../../src/model_parser.js';
import {auditModelTextureUsage} from '../performance-candidates/model-texture-usage.mjs';

// Counts public session API calls, not lower-level archive fallback attempts.
// Raw MDL references remain in memory only, then are parsed AFTER disconnect.
// Metadata timings include IO/queue waits and overlap; they are not CPU sums.
export function attachResourceAudit(session,{at=()=>performance.now(),maxModelBytes=128*1024*1024,maxReads=200000}={}) {
  const reads=[],models=new Map(),originals=new Map();let retainedBytes=0,droppedReads=0,droppedModels=0,serial=0;
  for(const method of ['getResource','getTextureResource']) {
    if(typeof session[method]!=='function')throw Error('Audit session lacks '+method);
    const original=session[method];originals.set(method,original);
    session[method]=async function(name,type) {
      const row={id:++serial,method,name:String(name).toLowerCase(),type:type??null,start:at(),areaId:session.world?.areaId??null,generation:session.areaGeneration??null};
      try {
        const result=await original.call(this,name,type),bytes=method==='getTextureResource'?result.bytes:result;
        row.ms=at()-row.start;row.bytes=bytes?.byteLength??0;row.success=true;
        if(method==='getTextureResource'){row.type=result.type;row.extension=result.extension;}
        if(method==='getResource'&&type===2002&&!models.has(row.name)) {
          if(retainedBytes+row.bytes<=maxModelBytes){models.set(row.name,bytes);retainedBytes+=row.bytes;}else droppedModels++;
        }
        return result;
      } catch(error) {row.ms=at()-row.start;row.success=false;row.error=error.code??error.name;throw error;}
      finally {row.finishedAreaId=session.world?.areaId??null;row.finishedGeneration=session.areaGeneration??null;if(reads.length<maxReads)reads.push(row);else droppedReads++;}
    };
  }
  let detached=false;
  function detach(){if(detached)return;detached=true;for(const [method,original]of originals)session[method]=original;}
  return {
    detach,
    finish() {
      if(!session.closed)throw Error('Resource model audit must run after session disconnect');
      detach();const modelRows=[],catalog=new Set(),consumed=new Set();
      try {
        for(const [name,bytes]of models) {
          try {
            const model=parseModel(bytes),usage=auditModelTextureUsage(model);
            for(const map of usage.catalog)catalog.add(map);for(const map of usage.consumed)consumed.add(map);
            modelRows.push({name,sha256:createHash('sha256').update(bytes instanceof ArrayBuffer?new Uint8Array(bytes):bytes).digest('hex'),format:model.format,nodes:model.nodes.length,...usage});
          } catch(error) {modelRows.push({name,parseFailure:error.message});}
        }
        const unused=new Set([...catalog].filter(name=>!consumed.has(name))),groups=new Map();
        for(const row of reads) {
          const key=JSON.stringify([row.method,row.name,row.type,row.success]);let group=groups.get(key);
          if(!group)groups.set(key,group={method:row.method,name:row.name,type:row.type,success:row.success,count:0,bytes:0,waitMs:0});
          group.count++;group.bytes+=row.bytes??0;group.waitMs+=row.ms;
        }
        const unusedTextureReads=reads.filter(row=>row.method==='getTextureResource'&&unused.has(row.name));
        return {scope:'Instrumented API audit; never use timings as an uninstrumented FPS comparison. No resource payloads are saved.',reads,models:modelRows,groups:[...groups.values()],
          conservativeUnusedCatalog:[...unused].sort(),unusedTextureReads:unusedTextureReads.length,unusedTextureBytes:unusedTextureReads.reduce((sum,row)=>sum+(row.bytes??0),0),
          retainedModelBytes:retainedBytes,droppedReads,droppedModels,complete:!droppedReads&&!droppedModels&&modelRows.every(row=>!row.parseFailure&&!row.fallback)};
      } finally {models.clear();retainedBytes=0;}
    },
    dispose(){detach();models.clear();retainedBytes=0;},
  };
}

import {SceneCaptureArchive} from './scene_capture_archive.mjs';
import {captureMessage,captureView} from './scene_capture.mjs';

// An offline source of decoded input, never a NetworkPeer or a local simulation.
// Fully verify the event checksum before exposing even the first replay event.
export class SceneReplay {
 static async open(directory){
  const archive=await SceneCaptureArchive.open(directory),records=[];
  for await(const record of archive.events()){
   const event=record.event;
   if(event?.kind==='view')captureView(event.view);
   else if(event?.kind==='message'){if(!captureMessage(event.message))throw Error('Unsupported replay message');}
   else if(event?.kind!=='state'||typeof event.state?.phase!=='string')throw Error('Unsupported replay event');
   records.push(record);
  }
  if(!records.length)throw Error('Scene replay has no events');
  const opened=new Set();
  for(const {context,event}of records){
   if(!opened.has(context)){
    if(event.kind!=='state'||event.state.phase!=='connecting')throw Error('Replay context has no connection bootstrap');
    opened.add(context);
   }
  }
  return new SceneReplay(archive,records);
 }
 constructor(archive,records){
  this.archive=archive;this.records=records;this.origin=records[0].at;this.duration=records.at(-1).at-this.origin;
  this.views=records.filter(r=>r.event.kind==='view');this.contexts=new Map(Object.keys(archive.manifest.contexts).map(id=>['replay-'+id,id]));
  this.cursor=0;this.elapsed=-1;this.rejectedActions=new Map();this.acknowledgements=[];this.resolvers=new Map();this.states=new Map();
 }
 // Caller supplies a monotonic playback clock. Delivery never awaits renderer
 // work: a slow model must queue input just as it does in the actual client.
 advance(elapsed,deliver){
  if(!Number.isFinite(elapsed)||elapsed<0||elapsed<this.elapsed)throw Error('Replay clock must advance monotonically');
  this.elapsed=elapsed;
  while(this.cursor<this.records.length&&this.records[this.cursor].at-this.origin<=elapsed){
   const record=this.records[this.cursor++];if(record.event.kind==='view')continue;
   if(record.event.kind==='state')this.states.set('replay-'+record.context,record.event.state);
   deliver({sessionId:'replay-'+record.context,...structuredClone(record.event)});
  }
  return this.cursor===this.records.length;
 }
 resolver(sessionId){
  const context=this.contexts.get(sessionId);if(!context)throw Error('Unknown replay session');
  if(!this.resolvers.has(context))this.resolvers.set(context,this.archive.resolver(context));return this.resolvers.get(context);
 }
 areaReady(sessionId,generation){
  this.resolver(sessionId);if(!Number.isInteger(generation)||generation<1)throw Error('Invalid replay area acknowledgement');
  this.acknowledgements.push({sessionId,generation,elapsed:this.elapsed});return true;
 }
 rejectAction(name){this.rejectedActions.set(name,(this.rejectedActions.get(name)??0)+1);throw Object.assign(Error('Offline scene replay cannot send '+name),{code:'REPLAY_READ_ONLY'});}
 summary(){
  const kinds={},areas=[];for(const record of this.records){const e=record.event,k=e.kind==='message'?e.message.kind:e.kind;kinds[k]=(kinds[k]??0)+1;if(k==='client-area')areas.push({context:record.context,atMs:record.at-this.origin,id:e.message.area.id,resRef:e.message.area.resRef});}
  return{version:1,complete:true,events:this.records.length,eventsSha256:this.archive.manifest.eventsSha256,bytes:this.archive.manifest.bytes,durationMs:this.duration,kinds,areas,
   cameraSamples:this.views.length,firstView:this.views[0]?.event.view??null,lastView:this.views.at(-1)?.event.view??null,
   contexts:Object.entries(this.archive.manifest.contexts).map(([id,c])=>({id,resources:Object.values(c.resources).filter(r=>!r.missing).length,recordedMisses:Object.values(c.resources).filter(r=>r.missing).length,textures:Object.keys(c.textures).length,talkTables:Object.keys(c.resources).filter(k=>k.startsWith('__talk_'))})),
   unrecorded:[...this.archive.unrecorded].sort(),rejectedActions:Object.fromEntries(this.rejectedActions)};
 }
}

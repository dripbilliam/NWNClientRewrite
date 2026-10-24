import {SceneReplayTalk} from './scene_replay_talk.mjs';
// Shared by the private Electron launcher and CPU boundary tests. No installed
// resolver, credentials, NetworkPeer, UDP, or HTTP fallback exists here.
export class SceneReplayRequests {
 constructor(replay,{modelCache=null,allowTextGaps=false}={}){Object.assign(this,{replay,modelCache,allowTextGaps});this.textGaps=new Set();this.talk=new SceneReplayTalk();}
 async request(name,args){
  if(!Array.isArray(args))throw Error('Invalid replay request');
  if(name==='action')return this.replay.rejectAction(String(args[0]));
  const [id,ref,type]=args,resolver=this.replay.resolver(id);
  const state=this.replay.states.get(id);
  if(name!=='area-ready'&&(!state?.resourcesReady||state.closed))throw Error('Replay session resources are unavailable at this point in the recording');
  if(name==='resource')return resolver.getResource(ref,type);
  if(name==='texture')return resolver.getTextureResource(ref);
  if(name==='model'){
   if(!this.modelCache)throw Error('Replay model preparation is unavailable');
   if(type!==null&&type!==undefined&&!/^[a-f0-9]{64}$/.test(type))throw Error('Invalid replay model key');
   return this.modelCache.prepare(await resolver.getResource(ref,2002),{knownKey:type??null,metadata:true});
  }
  if(name==='area-ready')return this.replay.areaReady(id,ref);
  if(name==='talk'){
   const table=resolver.resourceRecord(ref&0x01000000?'__talk_custom':'__talk_main',2018);
   if(ref===0xffffffff||table&&!table.missing)return this.talk.read(resolver,ref,type??0);
   // Capture v1 did not intercept resolved talkString calls. An explicitly
   // requested exploratory render can retain UI placeholders, with a failed
   // completeness gate. Never silently invent text or report a parity pass.
   this.textGaps.add(id+':'+ref+':'+(type??0));
   if(!this.allowTextGaps)throw Object.assign(Error('Talk string was not captured'),{code:'CAPTURE_MISSING'});
   return{status:0,text:'[Unrecorded string '+ref+']',sound:'',durationBits:0,gender:type??0};
  }
  if(name==='talk-table')return resolver.getResource(ref?'__talk_custom':'__talk_main',2018);
  if(name==='audio'){
   if(![4,8].includes(type))throw Error('Invalid replay audio type');
   const types=type===4?[8,4]:[8];
   for(const chosen of types){const record=resolver.resourceRecord(ref,chosen);if(record&&!record.missing)return{type:chosen,bytes:await resolver.getResource(ref,chosen)};}
   if(types.every(t=>resolver.resourceRecord(ref,t)?.missing))throw Object.assign(Error('Recorded audio resource is unavailable'),{code:'RESOURCE_NOT_FOUND'});
   // A first-read capture may not include every hasResource probe. Treat the
   // unavailable selection as a coverage gap, never an installed lookup.
   this.replay.archive.unrecorded.add(id+':'+ref+':audio');throw Object.assign(Error('Audio selection was not captured'),{code:'CAPTURE_MISSING'});
  }
  throw Error('Unsupported offline replay request');
 }
}

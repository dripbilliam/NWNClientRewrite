import {NativeServerMessage,NativeMessageReader} from './native_message.js';
import {writeMapPinCreated,writeMapPinEnabled,receiveMapPin,findMapPin} from './map_pin_messages.js';
import {playerMessageLanguage,serverMessageLanguage} from './native_message_text.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';
import {encodeGffText} from './gff_text.js';
import {OBJECT_INVALID} from './game_object_array.js';
import {scriptSetMapPinEnabled} from './map_pin_script.js';
import {packAreaMapPins} from './area_message_pack.js';
import {readAreaMapPins} from './area_map_pin_reader.js';

// Local authority's in-process client delivery. This uses the native body
// writers/readers without pretending the current local panel has a transport
// PLAYER_ID. The complete network send coordinators remain separately tested.
// Client wire references retain bit31; they never allocate server object IDs.
export class MapPinRuntime{
 constructor(session){this.session=session;this.scene=null;this.gender=0;this.text=null;this.reported=new Set();this.deliveryCount=0;this.lastDelivery=null;this.sceneGeneration=0;this.loading=null;this.initialFailure=null;}
 record(code,message,context,severity='warning'){const key=`${code}:${context.strRef??''}`;if(this.reported.has(key))return;this.reported.add(key);runtimeDiagnostics.record(code,message,context,severity);}
 area(){
  const id=this.session.currentArea?.id;if(!Number.isInteger(id))throw new Error('Native local map-pin client area is unavailable');
  const clientObjectId=this.session.player?.id;
  if(this.scene?.areaId!==id||this.scene?.clientObjectId!==clientObjectId)this.scene={areaId:id,clientObjectId,nativeMapPins2b8:[],capacity:0};return this.scene;
 }
 providers(){const s=this.session;return{
  create:(m,...args)=>m.create(...args),writeObject:(m,id)=>m.writeObjectIdServer(id),writeFloat:(m,...args)=>m.writeFloat(...args),writeBool:(m,v)=>m.writeBool(v),payload:m=>m.getWriteMessage(),
  server:()=>s,serverLanguage:serverMessageLanguage,playerLanguage:(_s,id)=>{
   const clients=s.combat.broadcastProviders().clients(),known=clients.filter(c=>Number.isInteger(c.nativePlayerId48)&&Number.isInteger(c.nativeLanguage4c));
   if(known.length!==clients.length)this.record('map-pin.local-language-context','Local map-pin delivery has no transport language context; native module/embedded fallback is used',{...s.diagnosticContext(s.player.id),operation:'local-map-pin-delivery'});
   return playerMessageLanguage(known,id);
  },warning:site=>this.record(`map-pin.localized-${site}`,'Native map-pin localized-string lookup warning',{...s.diagnosticContext(s.player.id),site}),
  area:()=>this.area(),construct:()=>({nativeEnabled170:0,nativeType18c:0,nativeReference188:0,nativeText178:new Uint8Array()}),position:(o,v)=>{o.nativePosition38=[...v];},text:(o,v)=>{o.nativeText178=v.bytes?.slice()??new Uint8Array();},
  append:(a,o)=>{if(a.nativeMapPins2b8.length===a.capacity)a.capacity=a.capacity?2*a.capacity:16;a.nativeMapPins2b8.push(o);},find:findMapPin,
  gui:()=>null,refresh:()=>{throw new Error('Native local map-pin GUI refresh is unavailable');},setGender:g=>{this.gender=g;},
  talkString:id=>{const text=this.text?.strRef(id);if(text===undefined){this.record('map-pin.talk-string-unavailable','Client map-pin talk-table string is unavailable',{strRef:id,gender:this.gender});return{status:0,bytes:new Uint8Array()};}return{status:1,bytes:encodeGffText(text)};},
  referenceNumber:()=>{throw new Error('Native map-pin reference-number message is unavailable');},
 };}
 async deliver(client,minor,message,payload){
  if(client!==this.session.combat.broadcastProviders().client(this.session.player?.id))throw new Error('Local map-pin recipient is unavailable');
  const area=this.session.currentArea,player=this.session.player;let loading;
  while((loading=this.loading)&&loading.area===area&&loading.player===player){await loading.promise.catch(()=>null);if(this.loading===loading)break;}
  if(this.session.currentArea!==area||this.session.player!==player){
   this.record('map-pin.delivery-area-changed','Local map-pin delivery was superseded by a client area or character change',{requestedAreaId:area?.id,currentAreaId:this.session.currentArea?.id,clientObjectId:player?.id,minor},'info');return 0;
  }
  if(this.initialFailure?.area===this.session.currentArea&&this.initialFailure.player===this.session.player){
   // The initial loader already reported the cause. A missing local client
   // scene is a failed delivery, not an exception in a successful CreateObject.
   this.record('map-pin.delivery-area-unavailable','Map-pin delivery requires the unavailable initial client map state',{areaId:this.session.currentArea.id,minor});return 0;
  }
  if(!payload.status)return 0;
  // This is an in-process body route, not a network packet. OBJECT_INVALID
  // denotes absent transport metadata; no canonical actor ID is substituted.
  const reader=new NativeMessageReader(message.formatMode28,{diagnose:value=>runtimeDiagnostics.record('map-pin.message-read','Native local map-pin reader diagnostic',value)}),body=payload.data.slice(3,payload.length);
  if(!reader.setReadMessage(body,body.length,OBJECT_INVALID,1))return 0;
  const result=await receiveMapPin(reader,minor,this.providers());this.deliveryCount++;this.lastDelivery={minor,length:body.length,result,areaId:this.session.currentArea.id};return result;
 }
 async created(client,id,point,note,enabled){
  const temporary={strRef:note.strRef>>>0,entries:note.entries.map(e=>({key:e.key>>>0,bytes:e.bytes.slice()}))},message=new NativeServerMessage(1),payload=await writeMapPinCreated(message,id,point,temporary,enabled,this.providers());
  return this.deliver(client,6,message,payload);
 }
 async enabled(client,id,enabled){const message=new NativeServerMessage(1),payload=await writeMapPinEnabled(message,id,enabled,this.providers());return this.deliver(client,1,message,payload);}
 async loadArea({force=false}={}){
  const s=this.session,area=s.currentArea,player=s.player;if(!area||!player)return null;
  const client=s.combat.broadcastProviders().client(player.id);
  if(!client){this.sceneGeneration++;this.scene=null;this.initialFailure=null;return null;}
  if(!force&&this.scene?.initialLoaded&&this.scene.areaId===area.id&&this.scene.clientObjectId===player.id)return this.scene;
  if(!force&&this.loading?.area===area&&this.loading.player===player)return this.loading.promise;
  const generation=++this.sceneGeneration,task={area,player,promise:null};
  task.promise=(async()=>{
   const message=new NativeServerMessage(1);message.create(16,OBJECT_INVALID,1);
   const p=s.areaMessages.providers(message,{clients:[]}),common=this.providers();
   // Shared contiguous server section, not an invented full Area packet. The
   // local route uses the same explicit language-context adapter as Created.
   p.playerLanguage=common.playerLanguage;p.serverLanguage=common.serverLanguage;
   await packAreaMapPins(message,s.registry,area,client,p);const payload=message.getWriteMessage();
   if(!payload.status)throw new Error('Native local initial map-pin body is unavailable');
   const reader=new NativeMessageReader(1,{diagnose:value=>runtimeDiagnostics.record('map-pin.initial-message-read','Native local initial map-pin reader diagnostic',value)}),body=payload.data.slice(3,payload.length);
   if(!reader.setReadMessage(body,body.length,OBJECT_INVALID,1))throw new Error('Native local initial map-pin reader setup failed');
   const scene={areaId:area.id,clientObjectId:player.id,nativeMapPins2b8:[],capacity:0,initialLoaded:false};
   await readAreaMapPins(reader,scene,common);
   // These guards belong to this isolated local-body adapter. The original
   // two loops defer whole-area checks until after subsequent sections.
   if(reader.messageReadOverflow()||reader.messageReadUnderflow())throw new Error('Native local initial map-pin body was not consumed exactly');
   if(generation!==this.sceneGeneration||s.currentArea!==area||s.player!==player||s.combat.broadcastProviders().client(player.id)!==client)return null;
   scene.initialLoaded=true;this.scene=scene;this.initialFailure=null;return scene;
  })().catch(error=>{if(generation===this.sceneGeneration)this.initialFailure={area,player};s.report(error,{...s.diagnosticContext(player.id),areaId:area.id,area:area.resRef,operation:'local-initial-area-map-pins'});throw error;}).finally(()=>{if(this.loading===task)this.loading=null;});
  this.loading=task;return task.promise;
 }
 async setEnabled(args){const s=this.session,b=s.combat.broadcastProviders();return scriptSetMapPinEnabled(args,{
  waypoint:id=>{const o=s.registry.get(id);return o?.objectType===12?o:null;},message:()=>this,clients:b.clients,clientObject:c=>c.object?s.registry.get(c.object.id)??null:null,send:(_m,c,id,value)=>this.enabled(c,id,value),
 });}
}

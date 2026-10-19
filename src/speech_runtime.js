import {scriptSpeakStrRef,executeSpeakStrRef,sendChatStrRef,writeChatStrRef} from './speech_strref.js';
import {NativeServerMessage,NativeMessageReader} from './native_message.js';
import {addObjectAction} from './object_actions.js';
import {manageCreatureActivities} from './combat_attack_preparation.js';
import {OBJECT_INVALID} from './game_object_array.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';

export class SpeechRuntime{
 constructor(session){this.session=session;this.reported=new Set();this.lastDelivery=null;}
 record(code,message,context){if(this.reported.has(code))return;this.reported.add(code);runtimeDiagnostics.record(code,message,context);}
 providers(){const s=this.session;return{active:1,lookup:id=>{const object=s.registry.get(id);return{object,status:object?0:1};},asObject:o=>o&&o.objectType>=5&&o.objectType<=14?o:null,
  asCreature:o=>o?.objectType===5?o:null,area:o=>s.registry.get(o.areaId)??null,players:()=>s.combat.broadcastProviders().clients(),clientObject:c=>c.object,
  add:(o,...args)=>addObjectAction(o.objectActionState,...args),activityManager:(o,n)=>manageCreatureActivities(o,n,(...args)=>s.skills.clearActivity(...args)),setActivity:(...args)=>s.skills.clearActivity(...args),
  send:(client,id,channel,strRef,special)=>this.deliver(client,id,channel,strRef,special)};}
 script(command,selfId,strRef,volume){return scriptSpeakStrRef(command,selfId,strRef,volume,{...this.providers(),send:(...args)=>this.send(...args)});}
 execute(actor,node){return executeSpeakStrRef(actor,node,{...this.providers(),send:(...args)=>this.send(...args)});}
 send(channel,id,strRef){return sendChatStrRef(channel,id,strRef,this.providers());}
 async deliver(client,id,channel,strRef,special){
  const s=this.session,message=new NativeServerMessage(1),payload=await writeChatStrRef(message,id,strRef,{create:(m,...args)=>m.create(...args),writeObject:(m,id)=>m.writeObjectIdServer(id),writeDword:(m,...args)=>m.writeDword(...args),payload:m=>m.getWriteMessage()});
  if(!payload.status)return 0;
  // In-process body projection. No OBJECT_ID substitutes for transport PLAYER_ID.
  const reader=new NativeMessageReader(1);const body=payload.data.slice(3,payload.length);if(!reader.setReadMessage(body,body.length,OBJECT_INVALID,1))return 0;
  const wireActorId=reader.readObjectIdClient(),reference=reader.readDword(32);
  const recipients=client?[client]:s.combat.broadcastProviders().clients();
  if(special!==undefined)this.record('speech.local-broadcast-context','Shout uses a local client-list projection of native recipient0xfffffff7; complete network broadcast routing remains unavailable',{...s.diagnosticContext(id),specialRecipient:special});
  for(const recipient of recipients)s.onCombatMessage({type:'chat-strref',recipientId:recipient.object.id,actorId:id>>>0,wireActorId,strRef:reference,channel});
  this.lastDelivery={actorId:id>>>0,wireActorId,strRef:reference,channel,recipients:recipients.map(c=>c.object.id),length:body.length};
  this.record('speech.strref-presentation-unimplemented','String-reference speech reaches the message log; native overhead text, TLK token/voice processing and lip animation remain unavailable',{...s.diagnosticContext(id),strRef:reference,channel});return 1;
 }
}

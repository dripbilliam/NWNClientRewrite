import {scriptLogEntry,scriptLogTimestamp,writeDebugInfoString} from './script_log.js';
import {NativeServerMessage,NativeMessageReader} from './native_message.js';
import {encodeGffText,decodeGffText} from './gff_text.js';
import {OBJECT_INVALID} from './game_object_array.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';

export class ScriptLogRuntime{
 constructor(session,{debugMode=0,debugLogToPlayers=false,now=()=>new Date()}={}){
  if(!Number.isInteger(debugMode)||typeof debugLogToPlayers!=='boolean'||typeof now!=='function')throw new Error('Native script logging configuration is unavailable');
  this.session=session;this.debugMode100f0=debugMode|0;this.debugLogToPlayers=debugLogToPlayers;this.now=now;this.message=new NativeServerMessage(1);this.reportedLocalDelivery=false;
 }
 async execute(read,frame){
  const s=this.session;let popError;
  const status=await scriptLogEntry({pop:type=>{try{return{ok:true,value:read(type)};}catch(error){popError=error;return{ok:false};}},timestamp:()=>scriptLogTimestamp(this.now()),
   log:(text,native)=>runtimeDiagnostics.record('script.timestamped-log-entry',text,{...s.diagnosticContext(frame.self),script:frame.program.name,pc:frame.pc,native},'info'),
   debugMode:()=>this.debugMode100f0,configBool:(key,fallback)=>key==='server.log.debug-mode-sends-to-players.enabled'?this.debugLogToPlayers:fallback,
   players:()=>{const entries=s.combat.broadcastProviders().clients();return{entries,count:entries.length};},message:()=>this.message,send:(...args)=>this.deliver(...args)});
  if(status!==0)throw popError??new Error(`Native WriteTimestampedLogEntry failed (${status})`);
 }
 command(args,frame){let cursor=0;return this.execute(()=>{if(cursor>=args.length)throw new Error('Native WriteTimestampedLogEntry VM argument is unavailable');return args[cursor++];},frame);}
 stack(vm,frame){return this.execute(type=>vm.pop(frame,type),frame);}
 async deliver(message,client,text){
  const bytes=encodeGffText(text);
  const payload=writeDebugInfoString(message,{bytes,length:bytes.length},{create:(m,...args)=>m.create(...args),
   copyString:string=>({bytes:string.bytes.slice(0,string.length),length:string.length,capacity:string.length+1}),writeString:(m,...args)=>m.writeCExoString(...args),payload:m=>m.getWriteMessage()});
  if(!payload.status)return 0;
  // Decode a local message body without fabricating a network PLAYER_ID/header.
  // Native client receiver/window formatting has not been mapped yet.
  const body=payload.data.slice(3,payload.length),reader=new NativeMessageReader(1);if(!reader.setReadMessage(body,body.length,OBJECT_INVALID,1))return 0;
  const received=reader.readCExoString(32),decoded=decodeGffText(received.bytes??new Uint8Array());
  if(!this.reportedLocalDelivery){this.reportedLocalDelivery=true;runtimeDiagnostics.record('script-log.local-delivery','DebugInfo string uses local message-body delivery; native transport and client debug window formatting remain unavailable',this.session.diagnosticContext(client.object.id),'info');}
  this.session.onCombatMessage({type:'debug-info-string',recipientId:client.object.id,text:decoded,nativeMessage:{major:33,minor:5}});return 1;
 }
}

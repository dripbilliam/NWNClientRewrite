import {parseTalkTable} from './talk_table.js';
import {fetchTalkRecord,fetchTalkRecordSync,scriptGetStringByStrRefSync,createTalkRecord} from './native_talk_table.js';
import {decodeGffText} from './gff_text.js';
import {scriptStringBytes} from './script_string.js';
import {setCustomToken,scriptSetCustomToken,writeSetCustomToken} from './custom_tokens.js';
import {NativeServerMessage,NativeMessageReader} from './native_message.js';
import {OBJECT_INVALID} from './game_object_array.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';
import {parseTalkTokens} from './talk_tokens.js';
import {gameTalkTokenValue,loadNamedTalkTokens,clientTokenAlignmentRef} from './game_talk_tokens.js';
import {parse2da} from './area.js';
import {decodeResourceText,RESOURCE_TYPE} from './resource_archive.js';
import {creatureRoot} from './creature_rules.js';
import {intEntry} from './combat_stats.js';

// Server talk-table state is separate from the UI's display cache. The BYTE
// gender and native record caches persist across script calls in this session.
export class TalkTableRuntime{
 constructor(session){this.session=session;this.state={gender:0};this.base=[null,null];this.custom=[null,null];this.overrides=new Map();this.reported=new Set();this.tokens={records:[]};this.clientTokens=new WeakMap();this.lastTokenDelivery=null;this.namedTokens=null;}
 async loadNamedTokens(){
  try{this.namedTokens=loadNamedTalkTokens(parse2da(decodeResourceText(await this.session.resolver.getResource('stringtokens',RESOURCE_TYPE.TWO_DA))));}
  catch(error){this.namedTokens=[];runtimeDiagnostics.error(error,'load.string-tokens-failed',{resource:'stringtokens'});}
 }
 warning(line,owner='FetchInternal'){const key=`${owner}:${line}`;if(this.reported.has(key))return;this.reported.add(key);runtimeDiagnostics.record('text.native-tlk-warning','Native talk-table lookup warning',{...this.session.diagnosticContext(this.session.player?.id),nativeFunction:owner,nativeLine:line,gender:this.state.gender});}
 async loadFiles(files,customName=''){
  const selected=[...files],find=name=>{const found=selected.filter(f=>f.name.toLowerCase()===name.toLowerCase());if(found.length>1)throw new Error(`Talk-table file ${name} is ambiguous`);return found[0];};
  const pair=async name=>{const primary=find(`${name}.tlk`);if(!primary){runtimeDiagnostics.record('load.talk-table-unavailable','Talk-table file is unavailable',{file:`${name}.tlk`});return[null,null];}
   const male=parseTalkTable(await primary.arrayBuffer()).nativeFile,femaleFile=find(`${name}f.tlk`);
   // Native OpenFile aliases missing female to male. A present corrupt female
   // follows failure/cleanup instead; never swallow that parse error.
   const female=femaleFile?parseTalkTable(await femaleFile.arrayBuffer()).nativeFile:male;return[male,female];};
  this.base=[null,null];this.custom=[null,null];
  if(!selected.length)return;
  try{this.base=await pair('dialog');const custom=String(customName).replace(/\.tlk$/i,'');if(custom)this.custom=await pair(custom);if(this.base[0]&&this.session.resolver?.getResource)await this.loadNamedTokens();}
  catch(error){runtimeDiagnostics.error(error,'load.talk-table-failed',{customName});throw error;}
 }
 providers(){return{override:ref=>this.overrides.get(ref)??null,file:(custom,gender)=>(custom?this.custom:this.base)[gender],cached:(file,index)=>file.cache.get(index)??null,cache:(file,index,value)=>file.cache.set(index,value),
  warning:line=>this.warning(line),parse:(state,record)=>{record.text=this.parseBytes(record.text,state,this.tokens.records,(token,state)=>gameTalkTokenValue(token,state,{fetch:ref=>this.fetchBytesSync(ref,state),context:()=>{throw new Error('Native server named-token context is unavailable');},world:()=>{throw new Error('Native server named-token world provider is unavailable');},playerName:()=>{throw new Error('Native server named-token player provider is unavailable');},warning:line=>this.warning(line,'GetTokenValue')}));},size:file=>file.bytes.length,
  seek:(file,offset)=>{file.position=offset>>>0;return Number(file.position<=file.bytes.length);},read:(file,out,length)=>{const value=file.bytes.subarray(file.position,file.position+length);out.set(value);file.position+=value.length;return value.length;},
  allocate:length=>{if(length>64*1024*1024)throw new Error('Native TLK text allocation exceeds supported size');return{bytes:new Uint8Array(length),defined:new Uint8Array(length)};}};}
 async getString(ref,gender=0){
  const result=scriptGetStringByStrRefSync(this.state,ref,gender,this.providers());
  // VM strings preserve Western byte projections, matching its existing NCS/
  // GFF operations. Other script display encodings need a separate owner.
  const file=((ref>>>0)&0x01000000?this.custom:this.base)[this.state.gender];
  if(file&&![0,1,2,3,4].includes(file.language)&&!this.reported.has('encoding')){this.reported.add('encoding');runtimeDiagnostics.record('text.script-encoding-unimplemented','Non-Western script text retains bytes; complete localized script presentation is unavailable',{language:file.language,strRef:ref>>>0});}
  return decodeGffText(result);
 }
 fetch(ref,parse=0,out=createTalkRecord()){return fetchTalkRecord(this.state,ref,out,parse,this.providers()).then(status=>({status,record:out}));}
 parseBytes(input,state,custom,resolve){return parseTalkTokens(input,state,{custom,named:this.namedTokens??[],resolve});}
 fetchBytesSync(ref,state){const record=createTalkRecord();fetchTalkRecordSync(state,ref>>>0,record,0,this.providers());return record.text;}
 parseClient(text,{actor=null,gender=0,resolveName}={}){
  const client=this.session.combat.broadcastProviders().client(this.session.player?.id),tokens=client?this.tokensForClient(client).records:[],state={gender:gender===1?1:0,suppression4c:0,nativeB8:1,nativeBC:0};
  // Explicit local plain-text display context: color markup is disabled. This
  // does not reconstruct the native widget's color/check visibility controls.
  const missing=name=>{throw new Error(`Native named-token ${name} provider is unavailable`);},name=value=>{if(typeof resolveName!=='function')return missing('localized name');return scriptStringBytes(resolveName(value));};
  const first=o=>name(creatureRoot(o)?.FirstName),last=o=>name(creatureRoot(o)?.LastName);
  const fetch=ref=>this.fetchBytesSync(ref,state),number=(v,n)=>{if(!Number.isInteger(v))return missing(n);return v|0;},ruleText=(table,index,column)=>{if(!table)return missing(`rule table ${column}`);const result=intEntry(table,index,column);if(!result.found)return missing(`rule text ${column}`);state.gender=0;return fetch(result.value);},firstClass=o=>{const classes=creatureRoot(o)?.ClassList;if(!Array.isArray(classes)||!classes[0])return missing('first class import');return classes[0];};
  const raceName=(o,lower)=>ruleText(this.session.characterRules?.racialtypes,number(creatureRoot(o)?.Race,'race import')&65535,lower?'ConverNameLower':'ConverName');
  const p={fetch,context:()=>actor,object:o=>o?.objectType>=5&&o.objectType<=14?o:null,creature:o=>o?.objectType===5?o:null,stats:o=>o.stats?o:null,
   firstName:first,lastName:last,fullName:o=>{const root=creatureRoot(o);if(root?.FirstName===undefined&&root?.LastName===undefined)return scriptStringBytes(o.name??'');const a=first(o),b=last(o);return !a.length?b:!b.length?a:Uint8Array.from([...a,32,...b]);},
   deity:o=>scriptStringBytes(creatureRoot(o)?.Deity??''),alignmentScore:(o,law)=>{const value=creatureRoot(o)?.[law?'LawfulChaotic':'GoodEvil'];if(!Number.isInteger(value))return missing('alignment import');return value;},
   raceName,subrace:o=>{const root=creatureRoot(o),value=root?.Subrace??'';if(typeof value!=='string')return missing('subrace string import');if(value.length)return scriptStringBytes(value);const table=this.session.characterRules?.racialtypes;if(!table?.orderedRows)return missing('race count');const race=number(root?.Race,'race import')&65535;return race>=(table.orderedRows.length&255)?new Uint8Array():ruleText(table,race,'Name');},
   className:(o,lower)=>ruleText(this.session.characterRules?.classes,number(firstClass(o).Class,'first class import')&255,lower?'Lower':'Name'),classLevel:o=>number(firstClass(o).ClassLevel,'first class level'),
   alignment:(o,lower)=>{const root=creatureRoot(o),ref=clientTokenAlignmentRef(root?.LawfulChaotic,root?.GoodEvil,lower);state.gender=0;return fetch(ref);},
   world:()=>{const s=this.session;if(!s.module||!s.worldTimer)return missing('client world snapshot');const calendar=s.worldTimer.calendar();return{native160:calendar.year,native164:calendar.month,native16c:s.worldTimer.getHour(),native17c:number(s.module.nativeDawnHour3b9,'dawn import'),native17d:number(s.module.nativeDuskHour3ba,'dusk import')};},
   playerName:()=>missing('player lookup'),warning:line=>this.warning(line,'GetTokenValue')};
  const resolve=(token,state)=>{try{if(token.action>=19&&token.action<=22&&!this.reported.has('token-widget')){this.reported.add('token-widget');runtimeDiagnostics.record('text.token-widget-unimplemented','Tokens use a local plain-text widget; native rich-text color and widget visibility context remain unavailable',{actorId:actor?.id,actionCode:token.action});}return gameTalkTokenValue(token,state,p);}catch(error){const key=`token:${token.action}`;if(!this.reported.has(key)){this.reported.add(key);runtimeDiagnostics.error(error,'text.named-token-unimplemented',{actorId:actor?.id,actionCode:token.action,sourceRow:token.sourceRow});}return scriptStringBytes('<UNIMPLEMENTED TOKEN>');}};
  try{return decodeGffText(this.parseBytes(scriptStringBytes(text),state,tokens,resolve));}
  catch(error){runtimeDiagnostics.error(error,'text.token-parse-failed',{actorId:actor?.id});return text;}
 }
 setToken(id,text){return scriptSetCustomToken(id,scriptStringBytes(text),{set:(id,bytes)=>setCustomToken(this.tokens,id,bytes),players:()=>this.session.combat.broadcastProviders().clients(),object:client=>client.object,send:(...args)=>this.deliverToken(...args)});}
 tokensForClient(client){let state=this.clientTokens.get(client);if(!state){state={records:[]};this.clientTokens.set(client,state);}return state;}
 async deliverToken(client,id,bytes){
  if(client.nativePlayerId48!==undefined&&!Number.isInteger(client.nativePlayerId48))throw new Error('Native custom-token transport PLAYER_ID is unavailable');
  const message=new NativeServerMessage(1),playerId=client.nativePlayerId48??0xffffffff,payload=await writeSetCustomToken(message,playerId,id,bytes,{create:(m,...a)=>m.create(...a),writeInt:(m,...a)=>m.writeInt(...a),writeString:(m,...a)=>m.writeStringBytes(...a),payload:m=>m.getWriteMessage()});
  if(!payload.status)return 0;
  // Local scalar-body projection, not a reconstructed original client handler.
  // Absent transport metadata stays absent; no canonical actor ID is used as PLAYER_ID.
  const reader=new NativeMessageReader(1),body=payload.data.slice(3,payload.length);if(!reader.setReadMessage(body,body.length,OBJECT_INVALID,1))return 0;
  const tokenId=reader.readInt(32),value=reader.readCExoString(32);setCustomToken(this.tokensForClient(client),tokenId,value.bytes??new Uint8Array());this.lastTokenDelivery={tokenId,length:value.length,recipientId:client.object.id,bodyLength:body.length};
  if(!this.reported.has('token-network')){this.reported.add('token-network');runtimeDiagnostics.record('text.custom-token-network-unimplemented','Custom-token state and local message bodies are synchronized; complete native network/client receiver routing remains unavailable',{tokenId,recipientId:client.object.id});}return 1;
 }
}

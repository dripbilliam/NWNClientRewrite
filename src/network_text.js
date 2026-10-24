import {parse2da} from './area.js';
import {decodeResourceText,RESOURCE_TYPE} from './resource_archive.js';
import {loadNamedTalkTokens,gameTalkTokenValue} from './game_talk_tokens.js';
import {parseTalkTokens} from './talk_tokens.js';
import {setCustomToken} from './custom_tokens.js';
import {scriptStringBytes} from './script_string.js';
import {decodeGffText} from './gff_text.js';
import {intEntry} from './combat_stats.js';
import {nativeColorControlLength} from './native_rich_text.js';

// Reuse the original-derived parser and StringTokens2DA action dispatch.
// This adapter reads replicated identity/appearance/stats; missing stat/world/
// custom-token owners are diagnosed, never replaced by local rule evaluation.
export class NetworkText{
 constructor({world,getResource,talkString,diagnose}){Object.assign(this,{world,getResource,talkString,diagnose});this.cache=new Map();}
 rules(name){this.ruleTables??=new Map();if(!this.ruleTables.has(name))this.ruleTables.set(name,this.getResource(name,RESOURCE_TYPE.TWO_DA).then(bytes=>parse2da(decodeResourceText(bytes))));return this.ruleTables.get(name);}
 token(id,value){setCustomToken(this.world.customTokens,id,scriptStringBytes(value));}
 async raw(value,gender=0){
  if(value?.text!==undefined)return value.text;if(!value||!Number.isInteger(value.strRef)||value.strRef===0xffffffff)return'';
  const version=this.world.tlkOverrideVersion??0;if(this.overrideVersion!==version){this.overrideVersion=version;this.cache.clear();}if(this.world.tlkOverrides?.has(value.strRef))return this.world.tlkOverrides.get(value.strRef);
  const key=value.strRef+':'+(value.gender??gender);if(!this.cache.has(key))this.cache.set(key,this.talkString(value.strRef,value.gender??gender).then(r=>r.text));return this.cache.get(key);
 }
 async resolve(value,contextId,{playerId=0,playerName,nativeB8=1,nativeBC=0}={}){
  const input=await this.raw(value);if(!input.includes('<'))return input;
  this.tokens??=this.getResource('stringtokens',RESOURCE_TYPE.TWO_DA).then(bytes=>loadNamedTalkTokens(parse2da(decodeResourceText(bytes))));const tokens=await this.tokens;
  const context=this.world.registry.get(contextId),gender=context?.appearance?.gender??0,state={gender,nativeB8,nativeBC,nativeC0:playerId,suppression4c:0},names=context?.replicated?.name??context?.appearance?.name;
  const [first,last]=await Promise.all([this.raw(names?.firstName,gender),this.raw(names?.lastName,gender)]),references=new Set(),matched=[];
  const inputBytes=scriptStringBytes(input);
  for(let at=0;at<inputBytes.length&&inputBytes[at]!==0;at++){
   if(inputBytes[at]!==60)continue;if(inputBytes[at+1]===60){at++;continue;}
   const control=nativeColorControlLength(inputBytes,at);if(control){at+=control-1;continue;}
   const end=inputBytes.indexOf(62,at+1);if(end<0)break;
   const name=decodeGffText(inputBytes.subarray(at+1,end)),token=tokens.find(t=>decodeGffText(t.name)===name);at=end;
   if(token){matched.push(token);for(const ref of [token.defaultRef,...token.refs])references.add(ref>>>0);}
   else if(!/^CUSTOM\d+$/.test(name))this.diagnose('network.text-token-unhandled','Native network token data owner is unavailable',{token:name});
  }
  // Rule STRREFs are resolved asynchronously before the synchronous native
  // parser runs. Keep class order from the server (first, not highest class).
  // Only cache active tables/raw TLK; contextual values read current stats.
  const stats=context?.replicated?.stats,ruleRefs=new Map();
  await Promise.all(matched.map(async token=>{const action=token.action;if(![5,6,8,9].includes(action))return;try{const race=action<=6,table=await this.rules(race?'racialtypes':'classes'),id=race?stats?.racialType:stats?.classes?.[0]?.id;if(!Number.isInteger(id))return;const column=race?(action===6?'ConverNameLower':'ConverName'):(action===9?'Lower':'Name'),entry=intEntry(table,id&(race?65535:255),column);if(entry.found){ruleRefs.set(action,entry.value>>>0);references.add(entry.value>>>0);}}catch{/* The corresponding provider diagnoses missing rules below. */}}));
  const strings=new Map(await Promise.all([...references].flatMap(ref=>[...new Set([gender,0])].map(async g=>[ref+':'+g,scriptStringBytes(await this.raw({strRef:ref,gender:g}))]))));
  const unavailable=()=>{throw new Error('Replicated token provider is unavailable');},fetch=ref=>{const key=ref+':'+state.gender;if(!strings.has(key))throw new Error('Native token reference was not loaded');return strings.get(key);},ruleText=action=>{if(!ruleRefs.has(action))return unavailable();state.gender=0;return fetch(ruleRefs.get(action));},p={fetch,context:()=>context,object:o=>o,creature:o=>o?.objectType===5?o:null,stats:o=>o.replicated?.stats||o.replicated?.name||o.appearance?.name?o:null,
   firstName:()=>scriptStringBytes(first),lastName:()=>scriptStringBytes(last),fullName:()=>scriptStringBytes([first,last].filter(Boolean).join(' ')),world:unavailable,playerName:id=>{const name=id===playerId&&playerName!==undefined?playerName:this.world.players.get(id)?.name;return name===undefined?null:scriptStringBytes(name);},raceName:(_o,lower)=>ruleText(lower?6:5),subrace:unavailable,className:(_o,lower)=>ruleText(lower?9:8),classLevel:()=>stats?.classes?.[0]?.level,alignment:unavailable,alignmentScore:unavailable,deity:unavailable,warning:unavailable};
  return decodeGffText(parseTalkTokens(inputBytes,state,{controlLength:nativeColorControlLength,custom:this.world.customTokens?.records??[],named:tokens,resolve:(token,state)=>{try{return gameTalkTokenValue(token,state,p);}catch{this.diagnose('network.text-token-unhandled','Replicated token provider is unavailable',{action:token.action,sourceRow:token.sourceRow});return scriptStringBytes('<UNIMPLEMENTED TOKEN>');}}}));
 }
}

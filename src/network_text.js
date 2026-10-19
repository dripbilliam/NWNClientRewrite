import {parse2da} from './area.js';
import {decodeResourceText,RESOURCE_TYPE} from './resource_archive.js';
import {loadNamedTalkTokens,gameTalkTokenValue} from './game_talk_tokens.js';
import {parseTalkTokens} from './talk_tokens.js';
import {scriptStringBytes} from './script_string.js';
import {decodeGffText} from './gff_text.js';

// Reuse the original-derived parser and StringTokens2DA action dispatch.
// This adapter reads replicated identity/appearance only; missing stat/world/
// custom-token owners are diagnosed, never replaced by local rule evaluation.
export class NetworkText{
 constructor({world,getResource,talkString,diagnose}){Object.assign(this,{world,getResource,talkString,diagnose});this.cache=new Map();}
 async raw(value,gender=0){
  if(value?.text!==undefined)return value.text;if(!value||!Number.isInteger(value.strRef))return'';
  const key=value.strRef+':'+(value.gender??gender);if(!this.cache.has(key))this.cache.set(key,this.talkString(value.strRef,value.gender??gender).then(r=>r.text));return this.cache.get(key);
 }
 async resolve(value,contextId){
  const input=await this.raw(value);if(!input.includes('<'))return input;
  this.tokens??=this.getResource('stringtokens',RESOURCE_TYPE.TWO_DA).then(bytes=>loadNamedTalkTokens(parse2da(decodeResourceText(bytes))));const tokens=await this.tokens;
  const context=this.world.registry.get(contextId),gender=context?.appearance?.gender??0,state={gender,nativeB8:1,nativeBC:0,nativeC0:0,suppression4c:0},names=context?.replicated?.name??context?.appearance?.name;
  const [first,last]=await Promise.all([this.raw(names?.firstName,gender),this.raw(names?.lastName,gender)]),references=new Set();
  for(const match of input.matchAll(/<([^>]+)>/g)){
   const token=tokens.find(t=>decodeGffText(t.name)===match[1]);if(token)for(const ref of [token.defaultRef,...token.refs])references.add(ref>>>0);
   else this.diagnose('network.text-token-unhandled','Native network token data owner is unavailable',{token:match[1]});
  }
  const strings=new Map(await Promise.all([...references].map(async ref=>[ref,scriptStringBytes(await this.raw({strRef:ref,gender}))])));
  const unavailable=()=>{throw new Error('Replicated token provider is unavailable');},p={fetch:ref=>{if(!strings.has(ref))throw new Error('Native token reference was not loaded');return strings.get(ref);},context:()=>context,object:o=>o,creature:o=>o?.objectType===5?o:null,stats:o=>o.replicated?.name||o.appearance?.name?o:null,
   firstName:()=>scriptStringBytes(first),lastName:()=>scriptStringBytes(last),fullName:()=>scriptStringBytes([first,last].filter(Boolean).join(' ')),world:unavailable,playerName:unavailable,raceName:unavailable,subrace:unavailable,className:unavailable,classLevel:unavailable,alignment:unavailable,alignmentScore:unavailable,deity:unavailable,warning:unavailable};
  return decodeGffText(parseTalkTokens(scriptStringBytes(input),state,{custom:[],named:tokens,resolve:(token,state)=>{try{return gameTalkTokenValue(token,state,p);}catch{this.diagnose('network.text-token-unhandled','Replicated token provider is unavailable',{action:token.action,sourceRow:token.sourceRow});return scriptStringBytes('<UNIMPLEMENTED TOKEN>');}}}));
 }
}

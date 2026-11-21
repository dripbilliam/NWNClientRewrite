import {nativeRichText} from '../../src/native_rich_text.js';
import {intEntry} from '../../src/combat_stats.js';
import {nativeStringEntry} from '../../src/spell_metadata.js';
import {networkSpeechHasRemoteName,networkSpeechIsSystem} from '../../src/network_speech.js';

const prefixRef=channel=>({2:10300,9:10300,18:10300,3:10301,10:10301,19:10301,4:10302,20:10302,5:10299,15:10299,6:10303,22:10303,14:66756,30:66756})[channel];
export const richText=raw=>nativeRichText(String(raw??''));

// Data-only adaptation of existing speech/dialog/examine views. Resolution uses
// the same NetworkText owner and original resource tables; no server conditions,
// item rules, identification or undisclosed creature stats are evaluated here.
export class GameplayText {
 constructor({world,text}){Object.assign(this,{world,text});}
 resolve(value,id,options={nativeB8:0}){return this.text.resolve(value,id,options);}
 async rich(value,id){return richText(await this.resolve(value,id));}
 async name(value,id){
  const object=this.world.registry.get(id);
  value??=object?.replicated?.name??object?.appearance?.name??object?.item?.name??object?.staticState?.name;
  if(value?.firstName||value?.lastName)return(await Promise.all([this.resolve(value.firstName??{text:''},id),this.resolve(value.lastName??{text:''},id)])).filter(Boolean).join(' ');
  return value?this.resolve(typeof value==='string'?{text:value}:value,id):'';
 }
 async label(table,row,column='Name'){
  const entry=intEntry(await this.text.rules(table),row,column);
  return entry.found&&entry.value!==-1?this.resolve({strRef:entry.value>>>0}):'';
 }
 async speech(message){
  if(message.kind==='script-sound'||message.channel===7)return null;
  const system=networkSpeechIsSystem(message.channel),object=this.world.registry.get(message.objectId);
  if(!object&&!system&&![11,12].includes(message.channel)&&!networkSpeechHasRemoteName(message.channel))return null;
  const context=message.contextId??this.world.localObjectId,raw=await this.resolve(message.text,context);
  if(!raw)return null;
  const name=system?'':await this.name(message.speakerName,message.objectId)||await this.resolve({strRef:5189},message.objectId);
  const ref=prefixRef(message.channel),label=ref===undefined?'':await this.resolve({strRef:ref},context);
  const prefix=[14,30].includes(message.channel)&&label?'['+label+'] ':label;
  return{kind:'chat',channel:message.channel,system,objectId:message.objectId,name:richText(name),rich:richText(prefix+raw),text:nativeRichText(raw).text};
 }
 async notice(message){
  const prefix=await this.resolve({strRef:message.strRef},0x7f000000,{playerId:message.playerId,playerName:message.playerName,nativeB8:0});
  const raw=message.category==='journal'?prefix+' '+await this.resolve(message.title,0x7f000000):prefix+(message.suffix??'');
  return{kind:'chat',system:true,rich:richText(raw),color:message.color,category:message.category};
 }
 async dialog(message){
  const {kind}=message;
  if(kind==='dialog-close')return{kind};
  if(kind==='dialog-entry')return{kind,ownerId:message.ownerId,speakerId:message.speakerId,rich:await this.rich(message.text,message.tokenObjectId)};
  if(kind==='dialog-selected')return{kind,rich:await this.rich(message.text,message.tokenObjectId)};
  if(kind!=='dialog-replies')return null;
  const choices=message.replies.length?message.replies:[{id:0xffffffff,text:{text:''}}];
  const replies=await Promise.all(choices.map(async row=>{
   let label=await this.resolve(row.text,message.tokenObjectId);
   if(!label)label=await this.resolve({strRef:message.end||!message.replies.length?0x6ce:0x6cd,gender:0});
   return{id:row.id,rich:richText(label)};
  }));
  return{kind,entryId:message.entryId,end:message.end,replies};
 }
 async property(p){
  const defs=await this.text.rules('itempropdef'),text=await this.label('itempropdef',p.type,'GameStrRef');
  if(!text)throw Error('Native item property GameStrRef is unavailable');
  let cost=intEntry(defs,p.type,'CostTableResRef').value,param=intEntry(defs,p.type,'Param1ResRef'),parts=[text];
  const sub=nativeStringEntry(defs,p.type,'SubTypeResRef');
  if(sub.found&&sub.value&&sub.value!=='****'){
   parts.push(await this.label(sub.value,p.subtype));const table=await this.text.rules(sub.value),override=intEntry(table,p.subtype,'CostTableResRef');
   if(override.found&&override.value!==0)cost=override.value;const pp=intEntry(table,p.subtype,'Param1ResRef');if(pp.found)param=pp;
  }
  if(cost){const table=await this.text.rules('iprp_costtable'),name=nativeStringEntry(table,cost,'Name');if(name.found&&name.value!=='****')parts.push(await this.label(name.value,p.costValue));}
  if(param.found){const table=await this.text.rules('iprp_paramtable'),name=nativeStringEntry(table,param.value,'TableResRef');if(name.found&&name.value!=='****')parts.push(await this.label(name.value,p.uses));}
  return parts.filter(Boolean).join(' ');
 }
 async examine(message){
  const out={kind:'examine',targetId:message.targetId,type:message.type,close:Boolean(message.close||message.type==='trap'&&!message.success),facts:[],properties:[],effects:[],warnings:[]};
  if(out.close)return out;
  out.name=richText(await this.name(message.name,message.targetId)||'Examine');
  // Keep description independently of optional table failures. Never invent a
  // missing server-authored line (for example attunement gated by server feats).
  if(message.description)out.description=await this.rich(message.description,message.targetId);
  const fact=(name,value)=>out.facts.push({name,rich:richText(value)});
  try{
   if(message.type==='creature'&&message.hasDetails){
    out.condition=richText(await this.label('damagelevels',message.damageLevel,'STRING_REF'));
    if(message.reaction<=2)out.reaction=await this.rich({strRef:[0x1918,0x1919,0x1917][message.reaction]},message.targetId);
    if(message.challengeRating!==undefined)fact('Challenge Rating',String(message.challengeRating));
    if(message.playerLevel!==undefined)fact('Level',String(message.playerLevel));
    if(Number.isInteger(message.portraitId))out.portrait={id:message.targetId,portrait:message.portraitId,portraitRef:message.portrait};
   }
   if(message.type==='item'){
    const base=this.world.registry.get(message.targetId)?.item?.baseItem;if(base!==undefined)fact('Item type',await this.label('baseitems',base));
    if(message.identified&&message.charges>0)fact('Charges',String(message.charges));
    fact('Weight',String(message.weight/10));if(message.value!==undefined)fact('Value',String(message.value));
    if(!message.identified)fact('Identification','Unidentified');if(message.canUse!==undefined&&!message.canUse)fact('Use','Cannot use');
    if(message.minimumLevel!==undefined)fact('Required level',String(message.minimumLevel));
   }
   for(const p of message.properties??[])out.properties.push({rich:richText(await this.property(p)),usable:Boolean(p.usable)});
   for(const id of message.effects??[]){const label=await this.label('effecticons',id,'StrRef');if(label)out.effects.push(richText(label));}
   if(message.type==='trap'){fact('Trap',await this.label('traps',message.trapType,'TrapName'));if(message.assessment<=4)fact('Assessment',await this.resolve({strRef:0xcf98-message.assessment}));}
  }catch(error){out.warnings.push('Some examination details could not be loaded.');out.detailError=error.message;}
  return out;
 }
}

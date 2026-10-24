import {formatClientFeedback} from './client_feedback_format.js';
import {nativeRichText} from './native_rich_text.js';
import {OBJECT_INVALID} from './game_object_array.js';
import {parse2da} from './area.js';
import {RESOURCE_TYPE,decodeResourceText} from './resource_archive.js';
import {intEntry} from './combat_stats.js';
import {presentSpellCombatMessage} from './client_spell_message.js';
import {presentDamageFeedback} from './network_damage_feedback.js';
import {presentAttackFeedback} from './network_attack_feedback.js';
import {presentInitiativeFeedback} from './network_initiative_feedback.js';
import {presentScriptFloatingFeedback} from './network_script_feedback.js';
export const nativeDamageFeedbackOptions=()=>({enabled:true,total:false,color:'<c\x99\x99\xff>'});

// Presentation of server outcomes only. No attack roll, spell resolution,
// damage, creature mutation, object-ID conversion or local AI occurs here.
export class NetworkFeedbackView{
 constructor({world,text,tables,display,report,floating=null,options=nativeDamageFeedbackOptions}){Object.assign(this,{world,text,tables,display,report,floating,options});this.generation=0;this.ruleCaches=new WeakMap();}
 reset(){this.generation++;this.ruleCaches=new WeakMap();}
 async receive(message){
  const generation=this.generation,world=this.world(),text=this.text(),tables=this.tables();if(!world||!text)return;
  const current=()=>generation===this.generation&&world===this.world()&&text===this.text();
  const tlk=ref=>world.tlkOverrides.has(ref)?text.resolve({strRef:ref},OBJECT_INVALID):text.raw({strRef:ref});
  const table=async name=>{
   if(tables?.[name])return tables[name];let cache=this.ruleCaches.get(text);if(!cache)this.ruleCaches.set(text,cache=new Map());
   if(!cache.has(name))cache.set(name,text.getResource(name,RESOURCE_TYPE.TWO_DA).then(b=>parse2da(decodeResourceText(b))));return cache.get(name);
  };
  const string=async value=>{
   if(value.baseItem!==undefined){
    const name=intEntry(await table('baseitems'),value.baseItem,'Name');if(!name.found)throw new Error('Native feedback base-item name is unavailable');return tlk(name.value>>>0);
   }
   return text.raw(value);
  };
  const name=async id=>{
   const object=world.registry.get(id),player=[...world.players.values()].find(p=>p.character?.id===id||p.objectId===id),value=object?.replicated?.name??object?.appearance?.name??object?.item?.name??object?.staticState?.name??(player?.character?{firstName:player.character.firstName,lastName:player.character.lastName}:undefined);
   if(value===undefined)return null;
   if(value?.firstName||value?.lastName)return(await Promise.all([string(value.firstName??{text:''}),string(value.lastName??{text:''})])).filter(Boolean).join(' ');
   return string(typeof value==='string'?{text:value}:value);
  };
  try{
   const providers={tlk,string,name,token:(id,value)=>{if(current())text.token(id,value);},parse:(ref,options)=>text.resolve({strRef:ref},OBJECT_INVALID,options)};
   const append=(raw,flags,details)=>{if(!current()||!raw)return;const rich=nativeRichText(raw);this.display({system:true,...details,raw,text:rich.text,richText:rich.spans,flags});};
   if(message.kind==='combat-feedback'&&(message.type===93||message.type===94)){
    await presentScriptFloatingFeedback(message,{...providers,creature:id=>{const actor=world.registry.get(id);return current()&&actor?.objectType===5&&!actor.replicationRemoved?actor:null;},
     floating:event=>{if(!current())return;if(this.floating)this.floating(event);else this.report('network.feedback-floating-unhandled','Native floating-text renderer is unavailable',{objectId:event.objectId});},
     display:(raw,flags)=>append(raw,flags,{category:'script-feedback',type:message.type})});return;
   }
   if(message.kind==='initiative-feedback'){
    await presentInitiativeFeedback(message,{...providers,parse:ref=>providers.parse(ref,{nativeB8:0,nativeBC:0}),player:()=>{const actor=world.registry.get(world.localObjectId);return actor?.objectType===5?actor:null;},display:(raw,flags)=>append(raw,flags,{category:'initiative-feedback',sourceId:message.sourceId,roll:message.roll,modifier:message.modifier})});return;
   }
   if(message.kind==='attack-feedback'){
    const feats=message.minor===6?await table('feat'):null;let displayed=0;
    await presentAttackFeedback(message,{...providers,parse:ref=>providers.parse(ref,{nativeB8:0,nativeBC:0}),
     player:()=>{const actor=world.registry.get(world.localObjectId);return actor?.objectType===5?actor:null;},
     feat:id=>{if(id>=((feats.orderedRows?.length??feats.rows.size)&65535))return null;const name=intEntry(feats,id,'Feat');return name.found?{name:name.value}:null;},
     options:this.options,creature:id=>{const actor=world.registry.get(id);return actor?.objectType===5&&!actor.replicationRemoved?actor:null;},
     warning:warning=>{if(current())this.report('network.attack-feedback-warning',warning,{combatMode:message.combatMode,minor:message.minor});},
     display:(raw,flags)=>append(raw,flags,{category:displayed++?'attack-debug':'attack-feedback',sourceId:message.sourceId,targetId:message.targetId,result:message.result,attackType:message.attackType}),
     floating:event=>{if(!current())return;if(this.floating)this.floating(event);else this.report('network.feedback-floating-unhandled','Native floating-text renderer is unavailable',{objectId:event.objectId});}});
    return;
   }
   if(message.kind==='damage-feedback'){
    const [types,groups]=await Promise.all([table('damagetypes'),table('damagetypegroups')]);let displayed=0;
    await presentDamageFeedback(message,{...providers,cell:(which,row,column)=>intEntry(which==='types'?types:groups,row,column),typeRows:()=>types.orderedRows.length,
     player:()=>{const actor=world.registry.get(world.localObjectId);return actor?.objectType===5?actor:null;},options:this.options,target:id=>{const actor=world.registry.get(id);return actor&&!actor.replicationRemoved?actor:null;},
     display:(raw,flags)=>append(raw,flags,{category:displayed++?'damage-debug':'damage-feedback',sourceId:message.sourceId,targetId:message.targetId,damage:message.damage}),
     floating:event=>{if(!current())return;if(this.floating)this.floating(event);else this.report('network.feedback-floating-unhandled','Native floating-text renderer is unavailable',{objectId:event.objectId});}});
    return;
   }
   if(message.kind==='spell-feedback'){
    // The native client looks up spell metadata by signed row index; IDs are
    // never coerced into creature/object identities or simulated locally.
    const spells=await table('spells'),itemName=message.hasItem&&message.identified?await string(message.itemName):'';
    await presentSpellCombatMessage({...message,itemName},{...providers,sourceName:name,
     player:()=>{const actor=world.registry.get(world.localObjectId);return actor?.objectType===5?actor:null;},
     spell:id=>{if(id<0||id>=(spells.orderedRows?.length??spells.rows.size))return null;return{name:intEntry(spells,id,'Name').value,altMessage:intEntry(spells,id,'AltMessage').value};},
     baseItemName:id=>string({baseItem:id}),parse:ref=>providers.parse(ref,{nativeB8:0,nativeBC:0}),
     display:(raw,flags)=>append(raw,flags,{category:'spell-feedback',sourceId:message.sourceId,spellId:message.spellId,casting:message.casting,identified:message.identified,hasItem:message.hasItem})});
    return;
   }
   const result=await formatClientFeedback(message,providers);
   if(!current())return;
   if(!result){this.report('network.feedback-format-unhandled','Native feedback formatting branch is not implemented',{type:message.type,data:message.data});return;}
   append(result.raw,result.flags,{category:'combat-feedback',type:message.type,data:message.data});
  }catch(error){if(current())this.report('network.feedback-presentation-failed',error.message,{kind:message.kind,type:message.type,sourceId:message.sourceId,spellId:message.spellId});}
 }
}

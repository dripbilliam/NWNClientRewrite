import {gffField as field,gffRecord as record} from './gff_writer.js';
import {nativeGffLabel} from './native_gff_fields.js';
import {saveCombatInformation} from './combat_information_save.js';

const integer=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native SaveStats ${name} is unavailable`);return v|0;};
const byte=(v,name)=>integer(v,name)&255,short=(v,name)=>(integer(v,name)<<16)>>16;
const narrow=(v,t,name)=>{
 if(t===8){if(typeof v!=='number')throw new Error(`Native SaveStats ${name} FLOAT is unavailable`);return Math.fround(v);}
 if((t===10||t===11)&&typeof v!=='string')throw new Error(`Native SaveStats ${name} string is unavailable`);
 if(t===12&&(!v||typeof v!=='object'))throw new Error(`Native SaveStats ${name} localized string is unavailable`);
 return t===0?byte(v,name):t===1?(integer(v,name)<<24)>>24:t===2?integer(v,name)&65535:t===3?short(v,name):t===4?integer(v,name)>>>0:t===5?integer(v,name):v;
};
const bodyParts=['BodyPart_Neck','BodyPart_Torso','BodyPart_Belt','BodyPart_Pelvis','BodyPart_LShoul','BodyPart_LBicep','BodyPart_LFArm','BodyPart_LHand','BodyPart_LThigh','BodyPart_LShin','BodyPart_LFoot','BodyPart_RShoul','BodyPart_RBicep','BodyPart_RFArm','BodyPart_RHand','BodyPart_RThigh','BodyPart_RShin','ArmorPart_RFoot'];

// Complete CNWSCreatureStats::SaveStats1404145e0..14041524b coordinator.
// Lower stat, localization and class-info owners are supplied explicitly.
export async function saveCreatureStats(p,root=record({})){
 const put=(name,type,value)=>{root.fields[nativeGffLabel(name)]=field(type,narrow(value,type,name));};
 const s=p.stats,c=p.creature,locked=()=>integer(p.locked(),'equipment lock')!==0;
 const from=(read,names,type)=>{for(const name of names)put(name,type,read(name));};
 const extended=(name,type,value)=>{value=narrow(value,type,name);put(name,0,value<256?value:0);put(nativeGffLabel(`x${name}`),type,value);};
 put('DataMigration',5,s('DataMigration'));
 for(const name of ['FirstName','LastName','Description'])put(name,12,structuredClone(s(name)));
 put('DescriptionOverride',10,s('DescriptionOverride'));from(s,['IsPC','IsDM'],0);put('Tag',10,c('Tag'));
 put('Conversation',11,s('Conversation'));put('Interruptable',0,s('Interruptable'));put('Age',5,s('Age'));put('Gender',0,s('Gender'));
 put('Race',0,locked()?p.saved('Race'):s('Race'));put('Subrace',10,s('Subrace'));extended('StartingPackage',4,s('StartingPackage'));
 put('Deity',10,s('Deity'));put('MClassLevUpIn',0,s('MClassLevUpIn'));
 for(const name of ['willbonus','fortbonus','refbonus'])put(name,3,(integer(s(name),name)<<24)>>24);
 put('Gold',4,c('Gold'));
 if(!locked()){
  put('BaseAttackBonus',0,await p.baseAttack(0));put('RefSaveThrow',1,await p.save('reflex',0));
  put('WillSaveThrow',1,await p.save('will',0));put('FortSaveThrow',1,await p.save('fortitude',0));put('ArmorClass',3,await p.armor());
 }else{
  put('BaseAttackBonus',0,p.saved('BaseAttackBonus'));put('RefSaveThrow',1,p.saved('RefSaveThrow'));put('WillSaveThrow',1,p.saved('WillSaveThrow'));
  put('FortSaveThrow',1,p.saved('FortSaveThrow'));put('ArmorClass',3,p.saved('ArmorClass'));
 }
 put('OverrideBAB',0,s('OverrideBAB'));
 for(const name of ['Str','Dex','Con'])put(name,0,locked()?p.saved(name):s(name));
 from(s,['Int','Wis','Cha','NaturalAC'],0);
 put('SoundSetFile',2,locked()?p.saved('SoundSetFile'):c('SoundSetFile'));put('FootstepType',5,c('FootstepType'));
 put('Plot',0,integer(s('IsPC'),'PC flag')===0||await p.isDM()!==0?c('Plot'):0);
 from(c,['NoPermDeath','Disarmable','BodyBag'],0);
 put('HitPoints',3,c('HitPoints'));
 // Native samples the base HP BEFORE either virtual query.
 const base=short(c('HitPoints'),'base hit points'),maximum=short(await p.maximumHP(1),'maximum hit points'),current=short(await p.currentHP(1),'current hit points');
 put('CurrentHitPoints',3,base-maximum+current);
 let pregame;
 if(!locked()){put('MaxHitPoints',3,await p.maximumHP(1));pregame=await p.currentHP(1);}
 else{
  put('MaxHitPoints',3,p.saved('MaxHitPoints'));const limit=short(p.saved('MaxHitPoints'),'saved maximum hit points');
  const now=short(await p.currentHP(1),'current hit points');pregame=now<=limit?await p.currentHP(1):p.saved('MaxHitPoints');
 }
 put('PregameCurrent',3,pregame);put('Experience',4,s('Experience'));put('MovementRate',0,s('MovementRate'));
 if(!locked()){
  if(short(await p.portraitId(),'portrait ID')===-1)put('Portrait',11,await p.portrait());else put('PortraitId',2,await p.portraitId());
 }else{
  const id=integer(p.saved('PortraitId'),'saved portrait ID')&65535;
  if(id===65535)put('Portrait',11,p.saved('Portrait'));else put('PortraitId',2,id);
 }
 from(s,['GoodEvil','LawfulChaotic','Color_Skin','Color_Hair','Color_Tattoo1','Color_Tattoo2'],0);put('Phenotype',5,byte(s('Phenotype'),'phenotype'));
 put('Appearance_Type',2,locked()?p.saved('Appearance_Type'):s('Appearance_Type'));extended('Appearance_Head',2,s('Appearance_Head'));
 from(s,['Tail_New','Wings_New'],4);put('FactionID',2,s('FactionID'));put('ChallengeRating',8,s('ChallengeRating'));
 for(const name of bodyParts)extended(name,2,s(name));
 await p.classInfo(root);
 const cache=p.combatInformation(locked());if(!cache)throw new Error('Native SaveStats combat information is unavailable');
 const left=await p.item(cache.weaponIds[1]);if(left)cache.text[1]=await p.itemName(left,cache.text[1],0,0,true);
 const right=await p.item(cache.weaponIds[0]);
 if(right){
  cache.text[0]=await p.itemName(right,cache.text[0],0,0,true);const base=p.baseItem(right);
  if(byte(base.ranged,'ranged ammunition')!==0&&byte(base.weaponWield,'weapon wield')!==11){
   const ammoBase=p.baseItemById(byte(base.ranged,'ammunition base')),ammo=await p.equipped(integer(ammoBase.equipableSlots,'ammunition slots')>>>0);
   if(ammo){const text=await p.itemName(ammo,'',0,0,true);cache.text[0]=`${cache.text[0].split('\0')[0]} (${text.split('\0')[0]})`;}
  }
  cache.flags=byte(base.numDice,'weapon damage dice')|(byte(base.die,'weapon damage die')<<8);
 }
 saveCombatInformation(cache,root);return root;
}

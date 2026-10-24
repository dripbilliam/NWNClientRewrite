import {resolveCreatureModels} from './area.js';
import {intEntry} from './combat_stats.js';
import {nativeFloatEntry} from './movement_rate.js';

// Native appearance storage order, shared by item and creature replication.
export const CREATURE_BODY_FIELDS=['ArmorPart_RFoot','BodyPart_LFoot','BodyPart_RShin','BodyPart_LShin','BodyPart_LThigh','BodyPart_RThigh','BodyPart_Pelvis','BodyPart_Torso','BodyPart_Belt','BodyPart_Neck','BodyPart_RFArm','BodyPart_LFArm','BodyPart_RBicep','BodyPart_LBicep','BodyPart_RShoul','BodyPart_LShoul','BodyPart_RHand','BodyPart_LHand','BodyPart_Robe'];
const materialFields=['Leather1','Leather2','Cloth1','Cloth2','Metal1','Metal2'];
const paletteChannels=[6,7,4,5,2,3];
export function networkCreatureAppearance(object){
 const a=object.appearance;if(!a||!Number.isInteger(a.appearance))return null;
 const data={Appearance_Type:a.appearance,Appearance_Head:a.head??0,Phenotype:a.phenotype??0,Gender:a.gender??0,Race:object.replicated.stats?.racialType??object.replicated.stats?.fieldD20??0,
  Color_Skin:a.skin??0,Color_Hair:a.hair??0,Color_Tattoo1:a.tattoo1??0,Color_Tattoo2:a.tattoo2??0,XPosition:0,YPosition:0,ZPosition:0};
 for(const p of a.bodyParts??[])data[CREATURE_BODY_FIELDS[p.index]]=p.value;
 const armor=a.equipment?.find(e=>e.slot===2)?.item;
 if(armor?.modelType===3){for(const[i,value]of armor.parts.entries())data[CREATURE_BODY_FIELDS[i]]=value;for(const[i,name]of materialFields.entries())data['Color_'+name]=armor.colors[i];}
 return data;
}

// CreateBodyParts973de0: CAPart supplies names/anchors, Parts_Robe supplies
// numbered hide columns, and each of19 material rows overrides six channels.
// Robe IDs0..2 mean absent. Failed hide lookups hide that body part as native.
export function networkCreatureModelPlan(object,tables){
 const data=networkCreatureAppearance(object);if(!data)return null;
 const placement=resolveCreatureModels(data,object.id,{appearance:tables.appearance,racialTypes:tables.racialtypes,gender:tables.gender,phenotype:tables.phenotype});
 if(!placement||tables.appearance.rows.get(data.Appearance_Type)?.MODELTYPE!=='P')return placement;
 if(!tables.capart||!tables.parts_robe)throw Error('Native creature part/robe rules are unavailable');
 const armor=object.appearance.equipment?.find(e=>e.slot===2)?.item,robe=data.BodyPart_Robe??0;
 const parts=object.appearance.equipment?.some(e=>e.slot===1)?[]:placement.parts.filter(p=>p.node==='head_g');
 for(let index=0;index<19;index++){
  let id=data[CREATURE_BODY_FIELDS[index]]??0;
  if(index===18){if(id<=2)continue;}
  else if(robe>2){const column=tables.parts_robe.columns[index+2],hide=column?intEntry(tables.parts_robe,robe,column):{found:false};if(!hide.found||hide.value===1)continue;}
  if(!id)continue;
  const row=tables.capart.rows.get(index);if(!row?.MDLNAME||row.MDLNAME==='****'||!row.NODENAME||row.NODENAME==='****')throw Error('Native CAPart model/anchor is unavailable for '+index);
  const suffix='_'+row.MDLNAME.toLowerCase()+String(id).padStart(3,'0'),name=(placement.model+suffix).slice(0,16),fallback=(placement.fallbackModel+suffix).slice(0,16);
  const palette=[...placement.paletteColors];
  for(let channel=0;channel<6;channel++){const value=armor?.partColors?.[index]?.[channel];if(value!==undefined&&value!==255)palette[paletteChannels[channel]]=value;}
  const gender=tables.gender.rows.get(data.Gender).GENDER.toLowerCase(),phenotype=tables.phenotype.rows.get(data.Phenotype)?.DefaultPhenoType??'0';
  const pltCandidates=[...new Set([name,fallback,('p'+gender+'h'+phenotype+suffix).slice(0,16),('pmh0'+suffix).slice(0,16)])];
  parts.push({model:name,fallbackModel:fallback,pltCandidates,node:index===18?null:row.NODENAME,partIndex:index,paletteColors:palette,...(index===18?{nativeVisualScope:18}: {})});
 }
 return{...placement,parts};
}

// CreateHead978310: the equipped item's existing model replaces the bare
// head, attaches at head_g and uses the appearance row's gendered helmet scale.
export function nativeHelmetAttachment(object,tables){
 const entry=object.appearance?.equipment?.find(e=>e.slot===1);if(!entry)return null;
 const field=object.appearance.gender===1?'HELMET_SCALE_F':'HELMET_SCALE_M',scale=nativeFloatEntry(tables.appearance,object.appearance.appearance,field);
 return{itemId:entry.id,anchor:'head_g',scale:scale.found?scale.value:1,kind:'helmet'};
}

// CreateTail979d10/CreateWings97a5f0 use active model tables, including mounts
// represented by tailmodel rows. Slot IDs and attachment names are native;
// model names, colours and scale always come from this server's resource owner.
export function nativeCreatureAttachments(object,tables,paletteColors,report=()=>{}){
 const a=object.appearance;if(!a)return[];
 const cloak=object.appearance.equipment?.find(e=>e.slot===64)?.item?.parts?.[0]??0,hideRow=cloak?tables.cloakmodel?.rows.get(cloak):null;
 return[['fieldAA4','tailmodel','tail',253,'HIDETAIL'],['fieldAA8','wingmodel','wings',252,'HIDEWING']].flatMap(([field,table,anchor,scope,hide])=>{
  const id=a[field]??0;if(!id||Number.parseInt(hideRow?.[hide],10))return[];
  const row=tables[table]?.rows.get(id);if(!row){report('Native '+table+' row '+id+' is unavailable',{scope,id});return[];}
  if(!row.MODEL||row.MODEL==='****')return[];
  const scale=nativeFloatEntry(tables.appearance,a.appearance,'WING_TAIL_SCALE');
  return[{model:row.MODEL.toLowerCase().slice(0,16),node:anchor,nativeVisualScope:scope,paletteColors:[...paletteColors],scale:scale.found?scale.value:1}];
 });
}

// The native parts context forwards body playback to its separate robe Gob.
// This bridge shares the play request; each animator retains its own clocks,
// palette, visual curves and mesh, including server-provided AnimationSpeed.
export function relayRobeAnimation(source,robe){
 return relayCreatureAnimations(source,robe?[robe]:[]);
}
// Some server forms use a clipless invisible body with the visible creature
// attached at tail/wings. Keep that hierarchy and its visual scopes intact,
// but use an animated attachment for presentation clocks and hit events.
export function creatureAnimationSource(body,followers){
 return body?.model.animations.length?body:followers.find(a=>a.model.animations.length)??body;
}
export function networkBindingAnimator(binding){return binding.animator??binding.models[0]?.animator;}
export function relayCreatureAnimations(source,followers){
 if(!source||!followers.length)return()=>{};
 const play=source.play;
 source.play=function(name,options){const result=play.call(this,name,options);if(result)for(const follower of followers)follower.play(name,{...options,onComplete:null});return result;};
 if(source.clip)for(const follower of followers)follower.play(source.clip.name,{loop:source.loop});
 return()=>{source.play=play;};
}

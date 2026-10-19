import {OBJECT_INVALID} from './game_object_array.js';
import {intEntry} from './combat_stats.js';
import {nativeStringEntry} from './spell_metadata.js';
import {objectTemplateResRef} from './create_object.js';
import {normalizeNativeVector} from './native_vector.js';
import {constructClientProjectile} from './client_projectile_runtime.js';
const f=Math.fround,copy=v=>v.map(f),call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native ranged projectile provider ${n} is unavailable`);return p[n](...args);};
const hits=r=>r<11&&Boolean(0x4aa>>>r&1);

// Receiver7ac670 uses base-item BYTEac loaded from AmmunitionType at29dfa0.
// Prefer physical matching rows; only old tables missing either selector
// column use the native six-row-block fallback. No fixed model database.
export function clientRangedProjectileMetadata(rules,baseItem,appearance){
 const base=rules.baseitems,table=rules.ammunitiontypes;
 if(!base||!table)throw new Error('Native ranged projectile tables are unavailable');
 const rows=base.orderedRows??[...base.rows.values()];if((baseItem&255)===255||!rows[baseItem&255])return null;
 const ammunition=intEntry(base,baseItem&255,'AmmunitionType').value&255,signed=ammunition<<24>>24,columns=table.columns.map(c=>c.toLowerCase());let row=-1;
 if(columns.includes('ammunitiontype')&&columns.includes('damagerangedprojectile')){
  const rows=table.orderedRows??[...table.rows.values()];
  for(let i=0;i<rows.length;i++){const a=intEntry(table,i,'AmmunitionType'),d=intEntry(table,i,'DamageRangedProjectile');if(a.found&&a.value===signed&&d.found&&d.value===(appearance&255)){row=i;break;}}
  if(row===-1)return null;
 }else row=(signed+({0:-1,1:5,2:11,3:17,4:23,5:29}[appearance&255]??-1))|0;
 const model=nativeStringEntry(table,row,'Model');if(!model.value)return null;
 const shot=nativeStringEntry(table,row,'ShotSound'),impact=nativeStringEntry(table,row,'ImpactSound');
 return{ammunition,row,model:objectTemplateResRef(model.value),shotSound:objectTemplateResRef(shot.value),shotFound:shot.found,impactSound:objectTemplateResRef(impact.value)};
}

// Ranged branch7acc9b..7ae1b2 after bounded header decoding and missing-target
// dummy creation. All mutations belong to the local visual projectile/mirrors.
// Weapon damage, attack results and projectile lifetime arrive from the server.
export async function receiveClientRangedProjectile(header,p){
 const metadata=await call(p,'rangedMetadata',header.baseItem,header.appearance);if(!metadata)return[];
 const source=call(p,'object',header.sourceId>>>0),target=call(p,'object',header.targetId>>>0),ammo=metadata.ammunition&255;
 const delta=header.to.map((v,i)=>f(f(v)-f(header.from[i]))),length=f(Math.sqrt(f(f(f(delta[0]*delta[0])+f(delta[1]*delta[1]))+f(delta[2]*delta[2])))),direction=length<=f(.001)?call(p,'shortDirection',header):normalizeNativeVector(delta);
 let launch=[f(header.from[0]),f(header.from[1]),f(f(header.from[2])+1)];
 if(source){const model=call(p,'model',source);if(model){const position=[0,0,0],quaternion=[1,0,0,0];if(call(p,'nodePose',model,'rhand',position,quaternion)===1){
  launch=copy(position);const scale=({1:.6,2:.3,3:.4,6:.4})[ammo];if(scale!==undefined)launch=launch.map((v,i)=>f(v+f(direction[i]*f(scale))));if(ammo===2)launch[2]=f(launch[2]+f(.1));else if(ammo===3)launch[2]=f(launch[2]+f(.4));
 }}}
 if(metadata.shotFound)call(p,'oneShot',metadata.shotSound,copy(launch),13,1.5);
 const targetCreature=target?.objectType===5?target:null,sourceCreature=source?.objectType===5?source:null,appearance=targetCreature?call(p,'appearance',targetCreature)&65535:65535,sourceAppearance=sourceCreature?call(p,'appearance',sourceCreature)&65535:65535;
 const special=[103,116,298].includes(appearance),modelType=call(p,'modelType',sourceAppearance);let scale=1;
 if((modelType.includes('P')||modelType.includes('F'))&&sourceCreature){const entry=call(p,'weaponScale',sourceAppearance);if(entry.found)scale=entry.value>=f(1.2)?f(1.2):f(entry.value);}
 let temporary=false,part='impact';const result=header.result&255;
 if(!special&&call(p,'hitPartsEnabled')===0)temporary=true;
 else if(hits(result)){
  const type=call(p,'modelType',appearance);
  if(target&&call(p,'modelHandle',target)){
   const generic=(type.includes('P')||type.includes('F'))&&call(p,'random')%3===0;
   if(!generic){const model=call(p,'model',target);if(model)part=call(p,'randomImpactPart',model)??'';}
  }
 }
 if(![1,2,3,4,5,6].includes(ammo))return[];
 const state=constructClientProjectile(p);
 try{
  if(!await call(p,'loadModel',state,metadata.model,header.path)){call(p,'destroy',state);return[state];}if(state.destroyed)return[state];
  const model=call(p,'model',state);if(model)call(p,'modelScale',model,scale,0);call(p,'defaultMaterial',state);
  if(hits(result)){
   call(p,'setTarget',state,header.targetId,part);
   if(ammo===3)state.result=1;else if(targetCreature){call(p,'trackProjectile',targetCreature,state);state.trackedByTarget=1;}
   state.rangedEffect=1;state.impactCritical=Number(result===3||result===10);state.impactDamage=0;
  }else if(result===2){call(p,'setTarget',state,header.targetId,'');state.result=ammo===3?3:2+Number(header.path===13);}
  else{call(p,'setTarget',state,OBJECT_INVALID,'');state.endpoint=copy(header.to);}
  call(p,'setStage',state,1);call(p,'setPosition',state,copy(launch));call(p,'setOrientation',state,copy(direction));state.facing=2;state.remaining=state.totalTime=header.duration>>>0;
  state.impactSound=metadata.impactSound;state.impactDuration=temporary?0:8000;
  let path=header.path===13?13:2;
  if(ammo===3&&path!==13)path=hits(result)||result===2||header.to[2]===f(launch[2]+1)?11:12;
  call(p,'configurePath',state,path);call(p,'setScene',state,1);call(p,'ready',state);return[state];
 }catch(error){call(p,'destroy',state);throw error;}
}

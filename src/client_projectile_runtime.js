import {OBJECT_INVALID} from './game_object_array.js';
import {castingSpell,spellStringEntry} from './spell_metadata.js';
import {objectTemplateResRef} from './create_object.js';
import {scriptStringToInt} from './script_string.js';
import {normalizeNativeVector} from './native_vector.js';
import {receiveClientRangedProjectile} from './client_ranged_projectile.js';
const f=Math.fround,copy=v=>v.map(f),call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native client projectile provider ${n} is unavailable`);return p[n](...args);};
const lower=s=>s.split('\0')[0].replace(/[A-Z]/g,c=>c.toLowerCase());

// Additional CNWSpell fields consumed by7ac670/9876a0. Native CResRef width,
// not a spell-name/ID database. Resource resolution owns case folding.
export function clientProjectileSpell(rules,id){
 const spell=castingSpell(rules,id);if(!spell)return null;
 const text=name=>spellStringEntry(rules.spells,id|0,name),ref=name=>objectTemplateResRef(text(name)),spawn=lower(text('ProjSpwnPoint')),orientation=lower(text('ProjOrientation'));
 return{...spell,model:ref('ProjModel'),castHead:ref('CastHeadVisual'),castHand:ref('CastHandVisual'),castGround:ref('CastGrndVisual'),castSound:ref('CastSound'),projectileSound:ref('ProjSound'),
  conjure:['ConjHeadVisual','ConjHandVisual','ConjGrndVisual'].map(ref),conjureSoundMale:ref('ConjSoundMale'),conjureSoundFemale:ref('ConjSoundFemale'),conjureSound:ref('ConjSoundVFX'),
  spawn:spawn==='hand'?1:spawn==='head'?2:spawn.startsWith('monster')?3+Math.max(0,Math.min(9,scriptStringToInt(spawn.slice(7)))):0,
  facing:orientation==='target'?1:orientation==='path'?2:0};
}

// Native CNWCProjectile9832a0 fields used by the receiver/path/AI owners.
// Common scene/model storage is represented by the injected presentation.
export function constructClientProjectile(p){
 const state={id:OBJECT_INVALID,objectType:8,position:[0,0,0],orientation:[0,0,0],endpoint:[0,0,0],previousPosition:[0,0,0],velocity:[0,0,0],acceleration:[0,0,0],nodes:[],node:null,model:null,stage:0,
  lastTime:{...call(p,'worldTime')},remaining:0,totalTime:0,elapsed:0,tracked:1,loopStarted:0,phase:0,faceCamera:0,path:0,attachOnImpact:1,impactDuration:1,sound:null,loopSound:'',impactSound:'',result:0,rangedEffect:0,spellId:0,spiralSide:0,facing:0,impactNode:'impact',auxiliaryModel:null,destroyed:false};
 call(p,'register',state);call(p,'registerAI',state);return state;
}

// Receiver7ac670. Header/OBJECTID conversion are separate.
// Dummy, model/scene, casting visual and path owners are explicit services.
export async function receiveClientSpellProjectile(header,p){
 let targetId=header.targetId>>>0;
 const source=call(p,'object',header.sourceId>>>0),target=call(p,'object',targetId);
 if(targetId!==OBJECT_INVALID&&!target){const outcome=await call(p,'createDummy',targetId,copy(header.to),header.duration>>>0);if(!outcome)return[];targetId=outcome.targetId>>>0;}
 if(header.appearance!==6&&header.appearance!==7)return receiveClientRangedProjectile({...header,targetId},p);
 const spell=call(p,'spell',header.spellId|0);if(!spell)return[];
 const path=header.appearance===6?spell.projectilePath:header.path&255,launch=copy(header.from);launch[2]=f(launch[2]+1);
 if(source){
  if(source.objectType===5)call(p,'castVisuals',source,spell.castHead,spell.castHand,spell.castGround);
  const model=call(p,'model',source);
  if(model){const name=spell.spawn===1?'handconjure':spell.spawn===2?'headconjure':spell.spawn>=3&&spell.spawn<=12?`monster${spell.spawn-3}`:'root';call(p,'nodePose',call(p,'model',source),name,launch,[1,0,0,0]);}
 }
 if(spell.castSound)call(p,'oneShot',spell.castSound,source?copy(source.position):copy(header.from),11,1.5);
 if(spell.useProjectile===0)return[];
 const delta=header.to.map((v,i)=>f(f(v)-f(header.from[i]))),length=f(Math.sqrt(f(f(f(delta[0]*delta[0])+f(delta[1]*delta[1]))+f(delta[2]*delta[2]))));
 // The native near-zero direction branch must be established before a scene
 // orientation can be supplied; providers retain its explicit failure boundary.
 const direction=length<=f(.001)?call(p,'shortDirection',header):normalizeNativeVector(delta),created=[];
 let count=1;
 for(let i=0;i<count;i++){
  const projectile=constructClientProjectile(p);created.push(projectile);
  try{
   projectile.spellId=header.spellId|0;projectile.loopSound=projectile.impactSound=spell.projectileSound;projectile.faceCamera=0;projectile.facing=spell.facing&255;
   // The extra local path argument lets asynchronous adapters prefetch optional
   // endpoint assets before the synchronous native initializer is dispatched.
   if(!await call(p,'loadModel',projectile,spell.model,path)){call(p,'destroy',projectile);continue;}
   if(projectile.destroyed)continue;
   call(p,'setPosition',projectile,copy(launch));if(path!==7)call(p,'setOrientation',projectile,copy(direction));
   call(p,'setScene',projectile,1);projectile.remaining=projectile.totalTime=header.duration>>>0;
   call(p,'setStage',projectile,1);projectile.endpoint=copy(header.to);
   call(p,'setTarget',projectile,targetId,'');call(p,'configurePath',projectile,path);call(p,'ready',projectile);
   if(i===0&&path===4)count=5;
  }catch(error){call(p,'destroy',projectile);throw error;}
 }
 return created;
}

// AIUpdate983860 phase/timer/sound ordering. Impact attachment and camera
// orientation retain separate native owners. Path motion already has an oracle.
export function updateClientProjectile(state,now,p){
 state.elapsed=call(p,'difference',now,state.lastTime).time>>>0;
 if(state.phase===1){const saved=state.remaining;state.remaining=0;call(p,'updatePath',state);state.remaining=saved;}else call(p,'updatePath',state);
 if(state.tracked===1){
  if(state.sound)call(p,'updateSound',state.sound,copy(state.position),1.5);
  if(state.phase===1){
   const camera=call(p,'camera');if(state.faceCamera!==0)call(p,'faceCamera',state,camera);
   if((state.elapsed>>>0)<(state.remaining>>>0))state.remaining=(state.remaining-state.elapsed)>>>0;else state.remaining=0;
   if(state.remaining===0){call(p,'setScene',state,0);if(state.sound)call(p,'destroySound',state.sound);call(p,'destroy',state);return;}
  }else if(call(p,'getStage',state)===1||call(p,'getStage',state)===0){
   if(state.loopStarted===0){
    if(state.sound){call(p,'destroySound',state.sound);state.sound=null;}
    if(state.loopSound){state.sound=call(p,'createSound',state.loopSound);if(state.sound){call(p,'soundPriority',state.sound,12);call(p,'sound3d',state.sound,1);call(p,'soundLooping',state.sound,1);call(p,'updateSound',state.sound,copy(state.position),1.5);call(p,'playSound',state.sound);}}
   }
   state.loopStarted=1;
   if(state.remaining===0){
    call(p,'setStage',state,2);state.phase=1;
    if(state.sound){call(p,'stopSound',state.sound);call(p,'destroySound',state.sound);state.sound=null;}
    if(state.impactSound)call(p,'oneShot',state.impactSound,copy(state.position),12,0);
    if(state.attachOnImpact===1){call(p,'attachImpact',state);state.remaining=state.impactDuration>>>0;}else state.remaining=0;
   }
  }
 }
 state.lastTime={...now};
}

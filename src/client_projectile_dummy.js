import {OBJECT_INVALID} from './game_object_array.js';
const f=Math.fround,call=(p,key,...args)=>{if(typeof p[key]!=='function')throw new Error(`Native projectile dummy provider ${key} is unavailable`);return p[key](...args);};

// Constructor projection: only cells consumed by the dummy/expiry owners.
// Original creature constructor and base761760 remain separate research owners.
export function createClientDummyState(){return{id:OBJECT_INVALID,objectType:5,nativeField28:0,position:[0,0,0],orientation:[0,0,0],desiredPosition:[0,0,0],model:null,temporary:0,blocked:0,fadeState:1,fadeTarget:1,delayEnabled:0,duration:0,since:{day:0,time:0},opacity:1,visible:1,destroyed:false};}

// Object-visual receiver7857f0 uses the same creature/model/expiry owners but
// distinct admission and lifetime rules. SOURCE really aborts on status0 at
//785f9c; point785bde/target78616e abort on nonzero. Do not normalize this quirk.
// The caller retains its original source ID, even when a dummy was allocated.
export async function createClientVisualDummy(role,position,lifetime,p){
 if(!['point','source','target'].includes(role))throw new Error('Unknown native visual dummy role');
 const dummy=call(p,'construct');if(!dummy)return{dummy:null,registered:false,aborted:true};
 let registered=false;
 if(await call(p,'loadModel',dummy,'c_dummy',255,0)){
  const area=call(p,'currentArea');
  if(area){
   const result=call(p,'register',dummy);
   if(role==='source'?result.status===0:result.status!==0)return{dummy,registered,aborted:true};
   call(p,'setId',dummy,result.id>>>0);call(p,'setArea',dummy,area);call(p,'registerAI',dummy);call(p,'setScene',dummy,area);call(p,'setPosition',dummy,position.map(f));dummy.desiredPosition=position.map(f);dummy.appearance=201;registered=true;
  }
 }
 call(p,'setDelay',dummy,1,1,lifetime>>>0);dummy.temporary=1;
 return{dummy,registered,aborted:false};
}

// Missing-target receiver7aca8e..7acc54. c_dummy is an MDL resource, not UTC;
// appearance201 is written after registration and does not replace that model.
export async function createClientProjectileDummy(targetId,position,travel,p){
 targetId>>>=0;if(targetId===OBJECT_INVALID)return{targetId,dummy:null,aborted:false};
 const dummy=call(p,'construct');if(!dummy)return{targetId,dummy:null,aborted:true};
 let registered=false;
 if(await call(p,'loadModel',dummy,'c_dummy',255,0)&&call(p,'player')){
  const area=call(p,'area',call(p,'player'));
  if(area){
   const result=call(p,'register',dummy);if(result.status!==0)return{targetId,dummy,registered,aborted:true};
   call(p,'setId',dummy,result.id>>>0);call(p,'setArea',dummy,area);call(p,'registerAI',dummy);call(p,'setScene',dummy,area);call(p,'setPosition',dummy,position.map(f));dummy.desiredPosition=position.map(f);dummy.appearance=201;targetId=dummy.id>>>0;registered=true;
  }
 }
 call(p,'setDelay',dummy,1,1,((travel>>>0)+500)>>>0);dummy.temporary=1;
 return{targetId,dummy,registered,aborted:false};
}

// Creature AI7fc56c..7fc5d2 removes AI before object-array deletion. Destructor
// runs only for status0 plus a nonnull removed pointer, independent of104.
export function updateClientProjectileDummy(dummy,p){
 if(call(p,'expired',dummy)!==0){call(p,'removeAI',dummy);const deleted=call(p,'deleteObject',dummy.id>>>0);if(deleted.status===0&&deleted.object){call(p,'destroy',dummy);return 1;}}
 return 0;
}

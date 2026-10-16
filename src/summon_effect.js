import {OBJECT_INVALID} from './game_object_array.js';

// ExecuteCommandEffectSummonCreature14051bf80. The original groups its fifth
// and sixth arguments under argc>=6; argc5 retains the default unsummon visual.
export function constructSummonEffect(args,self,p){
  const effect=p.create(6,OBJECT_INVALID,[],8),name=String(args[0]);
  const visual=args.length>=2?args[1]|0:-1,delay=args.length>=3?Math.fround(args[2]):0,
    appear=args.length>=4?args[3]|0:0,unsummon=args.length>=6?args[4]|0:99,
    target=args.length>=6?args[5]>>>0:OBJECT_INVALID;
  if(args.length>=6&&name.length===0){
    const creature=p.creature(target);
    if(creature&&creature.nativeStatsIsPCb0!==0){effect.type=0;return effect;}
  }
  p.setCreator(effect,self);effect.strings??=Array(6).fill('');effect.strings[0]=name;
  effect.objectIds[0]=OBJECT_INVALID;effect.objectIds[2]=target;
  effect.integers[0]=visual;effect.integers[1]=appear;effect.integers[2]=1;effect.integers[3]=unsummon;effect.floats[3]=delay;
  return effect;
}

// OnApplySummonCreature140433d70. Its return is the native consumed flag:
// failed existing adoption or template loading is consumed.
export async function applySummonEffect(object,effect,loading,p){
  if(loading===1)return 0;
  const actor=p.asCreature(object);if(!effect||!actor)return 0;
  const name=effect.strings?.[0]??'';
  if(name.length===0){
    const target=p.creature(effect.objectIds[2]);
    if(!target||target.masterId!==OBJECT_INVALID)return 1;
    if(target&&target.masterId===OBJECT_INVALID){
      const visual=effect.integers[0]|0;
      if(visual!==-1){const area=p.area(target);if(area)await p.visual(area,visual,p.position(target),p.orientation(actor));}
      effect.objectIds[1]=effect.objectIds[2];await p.addAssociate(actor,effect.objectIds[2],4);
    }
    return 0;
  }
  const target=await p.construct();
  if(effect.objectIds[0]===OBJECT_INVALID){
    effect.objectIds[0]=object.areaId;const point=p.position(object);for(let i=0;i<3;i++)effect.floats[i]=Math.fround(point[i]);
  }
  const area=p.areaById(effect.objectIds[0]);
  if(!area){if(target)await p.destroy(target);return 0;}
  let point=effect.floats.slice(0,3).map(Math.fround);
  const delay=effect.floats[3]>0?Math.fround(effect.floats[3]):0;
  const resRef=name.split('\0')[0].slice(0,16).toLowerCase();
  if(await p.load(target,resRef,0)===0){await p.warning('OnApplySummonCreature: Invalid Creature file');if(target)await p.destroy(target);return 1;}
  const safe=[0,0,0];
  if(await p.safeLocation(area,point,20,target.nativePathInfo,0,safe)===1){point=safe.map(Math.fround);point[2]=Math.fround(await p.height(area,point));}
  const visual=effect.integers[0]|0;
  if(visual!==-1)await p.visual(area,visual,point,p.orientation(actor));
  const data={floats:[...point],objectIds:[target.id],integers:[effect.integers[1]|0]};
  const day=await p.day(delay),time=await p.time(delay);
  await p.enqueue(day,time,object.id,object.id,24,data);
  effect.objectIds[1]=target.id;
  await p.feedback(actor,154,{objects:[target.id]});return 0;
}

// OnRemoveSummonCreature140438ca0: no master/type/area condition here.
export async function removeSummonEffect(_object,effect,p){
  const target=p.creature(effect.objectIds[1]);if(target)await p.unsummon(target);return 1;
}

// Creature EventHandler24,14038fb0f..14038fc54. Placement uses the owner's
// area at delivery, independently of the area used by the apply coordinator.
export async function receiveSummonEvent(actor,data,p){
  const point=data.floats.slice(0,3).map(Math.fround),id=data.objectIds[0]>>>0,target=p.creature(id);
  if(target&&p.area(actor)){
    await p.addToArea(target,p.area(actor),...point,0,1);
    target.nativeSpawnState548=1;await p.runEventScript(target,8,null);
    await p.addAssociate(actor,id,4);
    const appear=data.integers[0]|0;
    if(appear!==0){const effect=p.createEffect(81,actor.id,[appear]);await p.applyEffect(target,effect,0,0);}
  }
}

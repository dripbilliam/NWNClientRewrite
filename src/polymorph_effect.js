import {OBJECT_INVALID} from './game_object_array.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native polymorph ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native polymorph provider ${n} is unavailable`);return p[n](...args);};
const value=(e,n)=>integer(e.integers[n],`integer${n}`);
const id=e=>{if(typeof e.id!=='string'||!/^[0-9a-f]{1,16}$/i.test(e.id))throw new Error('Native polymorph effect ID is unavailable');return BigInt('0x'+e.id);};

// ExecuteCommandEffectComplex1405185d7..140518830, command463. An old
// one/two-argument call omits the VFX override. argc>2 pops THREE more INTs.
// Despite the API parameter name, this binary stores an ABILITY SELECTOR,
// not a literal ability modifier. Preserve the observed unsigned<=5 branch.
export function constructPolymorph(args,self,p){
 const effect=call(p,'create',0,OBJECT_INVALID,[],0);
 if(!args.length||args.length>2&&args.length<5)throw new Error('Native polymorph constructor stack pop failed (-639)');
 const form=integer(args[0],'form'),locked=args.length>1?integer(args[1],'lock'):0,custom=Number(args.length>2),visual=custom?integer(args[2],'removal visual'):0;
 let ability=custom?integer(args[3],'ability selector'):-1;const caster=custom?integer(args[4],'caster level'):0;
 effect.type=62;effect.integers.splice(0,5,form,0,locked,custom,visual);
 if((ability>>>0)>5){
  ability=255;const actor=call(p,'creature',self);
  if(actor){
   const read=type=>{const info=call(p,'classInfo',type&255);if(!info)return null;let n=integer(info.castingAbility,'class casting ability')&255;return n===255?integer(info.primaryAbility,'class primary ability')&255:n;};
   const index=integer(actor.nativeSpellClass22c,'casting class')&255;
   if(index<=253){const found=read(call(p,'classType',actor,index));if(found!==null)ability=found;}
   else{const feat=integer(actor.nativeSpellFeat23c,'casting feat')&65535;
    if(feat!==65535&&call(p,'hasStats',actor)){const type=integer(call(p,'featSource',actor,feat),'feat source')&255;if(type!==255){const found=read(type);if(found!==null)ability=found;}}
   }
   if(ability===255){ability=0;const found=read(call(p,'classType',actor,0));if(found!==null)ability=found;}
  }
 }
 effect.integers[5]=1;effect.integers[6]=ability;effect.integers[7]=caster;
 effect.subtype=(effect.subtype&0xffcf)|8;call(p,'setCreator',effect,self);return effect;
}

// Complete OnApplyPolymorph140430950. The full form/equipment transform is
// a separate provider; its return value is deliberately ignored by this owner.
export async function applyPolymorph(object,effect,p,loading=0){
 const actor=call(p,'asCreature',object);if(!actor)return 1;
 if(loading!==0&&(call(p,'dead',object)!==0||call(p,'dying',actor)!==0)&&![3,4].includes(effect.durationType&7))return 1;
 if([7,8].includes(integer(actor.associateType,'associate type')&65535))return 1;
 if(integer(actor.nativeField97c,'equipment lock')!==0&&integer(actor.nativeField9f8,'override flag')!==0)return 1;
 const previous=call(p,'effects',actor).find(e=>(e.type&65535)===62&&id(e)!==id(effect));
 if(previous){previous.integers[1]=1;await call(p,'remove',actor,previous.id);}
 const form=value(effect,0);
 for(const [type,n]of [[67,51],[83,289]]){
  const child=call(p,'copyConstruct',effect,1);child.type=type;child.integers[0]=n;
  await call(p,'apply',object,child,loading);
 }
 await call(p,'transform',actor,form,effect,loading);
 actor.nativeField9f8=Number(value(effect,2)!==0);
 const client=call(p,'client',actor.id);if(client)await call(p,'notify',client,actor.id,1,value(effect,2));
 return 0;
}

// Complete OnRemovePolymorph140437c80. First ordinary removal changes the
// SAME record into a temporary half-second transition and returns0. The next
// callback untransforms and returns1. Keep this distinct from duration expiry.
export async function removePolymorph(object,effect,p){
 const actor=call(p,'asCreature',object);if(!actor)return 1;
 if(call(p,'dead',actor)!==0&&integer(actor.nativeField89c,'object PC flag')===0&&call(p,'possessed',actor)===0&&integer(actor.nativeDestroyableF0,'destroyable flag')!==0)return 1;
 if(value(effect,1)===0){
  const visual=value(effect,3)!==0?value(effect,4):85;
  if(visual>=0){const child=call(p,'create',30,actor.id,[visual],0);child.durationType=0;await call(p,'apply',actor,child,0);}
  effect.integers[1]=1;effect.durationType=1;
  const client=call(p,'client',actor.id);if(client)await call(p,'notify',client,actor.id,0,0);
  if(value(effect,2)===0){
   effect.duration=Math.fround(0.5);const now=call(p,'time'),delta=call(p,'delta',effect.duration),expiry=call(p,'addTime',now,delta);
   if(expiry.status!==0)throw new Error('Native polymorph expiry reads uninitialized failed-add outputs');
   effect.expiryDay=expiry.day>>>0;effect.expiryTime=expiry.time>>>0;call(p,'setExpiry',effect,expiry);return 0;
  }
  effect.duration=0;
 }
 await call(p,'untransform',actor,effect);return 1;
}

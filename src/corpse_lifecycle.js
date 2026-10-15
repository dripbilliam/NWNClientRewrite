import {OBJECT_INVALID} from './game_object_array.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native corpse lifecycle ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native corpse lifecycle provider ${n} is unavailable`);return p[n];};

// OnApplyDeath14042acf8..14042ad1c; capture BEFORE OnDeath/XP. Caller
// must supply the death effect's integer0, never the damage effect's amount.
export function deathCleanupFlag(actor,spectacular){
  spectacular=integer(spectacular,'death integer0');
  if((integer(actor.nativeField771,'field771')&255)===15)spectacular=1;
  return integer(actor.nativeDestroyableF0,'destroyable')!==0&&integer(actor.nativeNoPermDeath8bc,'no permanent death')===0?spectacular:0;
}

// OnApplyDeath14042b2dc..14042b513, after effect purge. This coordinator
// is independently ported, not connected to a partial bag/destructor owner.
export async function scheduleCorpseCleanup(actor,deathEffect,flag,context,p){
  flag=integer(flag,'captured cleanup flag');
  if(integer(actor.nativeField89c,'PC field')===0&&await required(p,'possessed')(actor)===0){
    const lootable=integer(actor.nativeLootable4e8,'lootable'),caller=integer(deathEffect.creatorId,'effect creator')>>>0;
    if(flag===0||lootable===1){
      if(lootable===0)await required(p,'enqueue')(11,caller,actor.id,integer(actor.nativeDecayTime4ec,'decay time')>>>0,null);
      else await required(p,'spawnBag')(actor);
    }else{
      await required(p,'spectacularEffect')(actor,119,context,0);
      await required(p,'enqueue')(11,caller,actor.id,3000,null);
    }
    const id=integer(actor.nativeField948,'encounter ID')>>>0;
    if(id!==OBJECT_INVALID){const encounter=required(p,'encounter')(id);if(encounter){
      await required(p,'removeActiveCount')(encounter,actor.nativeChallengeRatingD0,0);actor.nativeField94c=1;
    }}
  }else await required(p,'playerDeath')(actor);
}

// Creature EventHandler event11:14038f07a..14038f220. The first possession
// query's return is ignored, then the PC field is read again. Destroyable must
// be EXACT1; associate7/8 never enter destruction. The actual destructor and
// RemoveFromArea providers must complete all their native ownership work.
export async function receiveCorpseCleanup(actor,p){
  if(integer(actor.nativeField89c,'PC field')===0)await required(p,'possessed')(actor);
  const excluded=((integer(actor.associateType,'associate type')&65535)-7&65535)<=1;
  if(integer(actor.nativeField89c,'PC field')!==0||await p.possessed(actor)!==0||integer(actor.nativeDestroyableF0,'destroyable')!==1||excluded)return;
  if(await required(p,'dead')(actor)===1&&integer(actor.nativeLootable4e8,'lootable')===0)await required(p,'spawnBag')(actor);
  await required(p,'removeFromArea')(actor,0);
  if(await required(p,'area')(actor)){
    const area=await p.area(actor);if(!area)throw new Error('Native retained corpse area became null');
    for(let n=0;n<required(p,'trapCount')(area);n++){
      const object=required(p,'object')(required(p,'trapId')(area,n));if(object&&[7,10,9].includes(object.objectType))await required(p,'removeTrapObserver')(object,actor.id);
    }
  }
  if(integer(actor.nativeField94c,'encounter removed flag')===0){
    const encounter=required(p,'encounter')(integer(actor.nativeField948,'encounter ID')>>>0);
    if(encounter){await required(p,'removeActiveCount')(encounter,actor.nativeChallengeRatingD0,0);actor.nativeField94c=1;}
  }
  await required(p,'destroy')(actor,1);
}

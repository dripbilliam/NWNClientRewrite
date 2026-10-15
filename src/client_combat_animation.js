import {OBJECT_INVALID} from './game_object_array.js';
import {normalizeOrientation} from './combat_lifecycle.js';
const f=Math.fround;
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native client combat animation ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p?.[n]!=='function')throw new Error(`Native client combat animation provider ${n} is unavailable`);return p[n];};

// Client animation metadata has its own80-byte action record, separate from
// CNWSCombatAttackData. This local adaptation retains canonical object IDs;
// it is not a network packet encoder/decoder.
export function clientAttackAnimationRecord(data,targetId){
  return {type:1,duration:integer(data.animationDuration,'duration')&65535,result:integer(data.result,'result')&255,
    targetId:integer(targetId,'target ID')>>>0,reactionDelay:integer(data.reactionDelay,'reaction delay')&65535,
    reaction:integer(data.reactionAnimation,'reaction')&65535,reactionDuration:integer(data.attackDuration,'reaction duration')&65535,
    attackType:integer(data.attackType,'attack type')&65535,ranged:integer(data.ranged,'ranged flag'),weaponAttackType:integer(data.weaponAttackType,'weapon type')&255};
}

// Client range classifier140800780: native3D distance minus target hitdist,
// then prefattackdist ±.25. The owners of actual weapon/rules are providers.
export function clientAttackAnimationClass(actor,record,p){
  const target=required(p,'target')(record.targetId);if(!target||target.objectType!==5)return 2;
  if(![actor,target].every(o=>Array.isArray(o.position)&&o.position.length===3&&o.position.every(Number.isFinite)))throw new Error('Native client combat positions are unavailable');
  const [x,z,ny]=actor.position.map((v,i)=>f(f(v)-f(target.position[i]))),y=f(-ny);
  const distance=f(f(Math.sqrt(f(f(f(x*x)+f(y*y))+f(z*z))))-f(required(p,'hitDistance')(target)));
  const reach=f(required(p,'preferredDistance')(actor,record.weaponAttackType));
  return f(reach-f(.25))>distance?1:f(reach+f(.25))>=distance?2:3;
}

// Weapon class updater140811190. Providers resolve actual client equipment
// and active baseitems/appearance metadata; style is never selected by name.
export function clientWeaponAnimationClass(actor,p){
  const context=required(p,'context')(actor),right=required(p,'equipped')(actor,16),left=p.equipped(actor,32);
  let style=1,type=context.fieldDF;
  const size=item=>integer(required(p,'weaponSize')(actor,item),'relative weapon size');
  const info=item=>required(p,'baseInfo')(item);
  if(!right){
    if(!left)type=2;
    else{const base=info(left);if(base){if((integer(base.weaponWield,'left wield')&255)===7)style=2;type=2;}}
  }else{
    const base=info(right);if(base){
      const wield=integer(base.weaponWield,'right wield')&255,difference=size(right);
      if(((difference+2)>>>0)<=2&&!(wield<=10&&(0x570>>>wield&1))){
        if(!left){style=3;type=base.weaponType;}
        else{const other=info(left);if(other){
          const lw=integer(other.weaponWield,'left wield')&255;
          if(lw===7){style=4;type=base.weaponType;}
          else if(((size(left)+2)>>>0)<=2){style=lw===1?3:5;type=lw===1?base.weaponType:other.weaponType;}
          else required(p,'warning')('You have something in your left hand that should not be there');
        }}
      }else{
        style=difference===1&&wield!==8&&![4,5,6,10].includes(wield)?6:({4:8,8:7,5:9,6:10,10:11})[wield]??1;
        type=base.weaponType;
      }
    }
  }
  context.fieldDD=style;context.fieldDF=integer(type,'weapon class type')&255;return style;
}

// Directional defender hit choice shared by140810c20,14080ffd0,14080f7b0.
// These are model animations only; no server combat/effect state is changed.
function directionalReaction(actor,target,p){
  if(!target)throw new Error('Native directional hit target is unavailable');
  const base=integer(required(p,'baseAnimation')(target),'defender base animation')&65535;
  const body=({5:217,7:218,8:8,6:6})[base];if(body!==undefined)return body;
  if(target.objectType!==5||(integer(required(p,'lockTarget')(target),'defender lock target')>>>0)===(actor.id>>>0))return 215;
  const direction=normalizeOrientation(actor.position.map((v,i)=>f(f(v)-f(target.position[i])))),orientation=normalizeOrientation(required(p,'orientation')(target));
  // Preserve native add order Y-product + X-product + Z-product.
  const dot=f(f(f(f(-direction[2])*f(-orientation[2]))+f(direction[0]*orientation[0]))+f(direction[1]*orientation[1]));
  if(dot>=f(.707))return 215;if(dot<=f(-.707))return 216;
  const crossZ=f(f(orientation[0]*f(-direction[2]))-f(f(-orientation[2])*direction[0]));
  return crossZ<0?214:213;
}

// Normal-range selector14080ffd0. Its alternating attack-side byte170 is
// owned by the client presentation actor, independent of server side flags.
export function selectClientMeleeAnimation(actor,record,p){
  const branch=clientAttackAnimationClass(actor,record,p),context=required(p,'context')(actor);
  const target=required(p,'target')(record.targetId),side=integer(actor.side,'attack side')&255;
  let animation=9;
  if(branch===1){
    if(!target)return animation;
    const base=integer(required(p,'baseAnimation')(target),'defender base animation')&65535;
    const low=[5,7,8,6].includes(base)||required(p,'targetHeight')(target)==='L';animation=low?204:203;
    if(side===2){actor.side=1;context.fieldE0=1;}
    if(record.reaction===11||record.reaction===12)record.reaction=animation===203?209:210;
    else if(record.reaction===14)record.reaction=directionalReaction(actor,target,p);
    return animation;
  }
  if(branch===3){
    animation=205;if(side===2){actor.side=1;context.fieldE0=1;}
    if(record.reaction===12)record.reaction=207;
    else if(record.reaction===11)record.reaction=209;
    else if(record.reaction===14)record.reaction=directionalReaction(actor,target,p);
    return animation;
  }
  const monk=integer(required(p,'hasMonkClass')(actor),'Monk class flag')!==0;
  const style=integer(context.fieldDD,'weapon style')&255;
  const left=[1,2].includes(style)?required(p,'equipped')(actor,32):null;
  const shield=Boolean(left&&[14,15,56,57].includes(integer(required(p,'baseItem')(left),'left base item')));
  const weapon=required(p,'attackWeapon')(actor,record.weaponAttackType);
  if(side===1){
    if(weapon){
      const info=required(p,'baseInfo')(weapon);
      if(info)animation=draw(p)%100<=(integer(info.slashLeft,'left slash percentage')&255)?200:202;
    }else{
      const first=draw(p)%3;
      if(first===1)animation=monk&&draw(p)%2===0?265:202;
      else animation=monk&&draw(p)%3===0?263:200;
    }
    actor.side=2;context.fieldE0=2;
  }else{
    if(weapon){
      const info=required(p,'baseInfo')(weapon);
      if(info)animation=draw(p)%100<=(integer(info.slashRight,'right slash percentage')&255)?shield?202:201:202;
    }else{
      const first=draw(p)%3;
      if(first===1)animation=monk&&draw(p)%2===0?265:202;
      else if(monk&&draw(p)%3===0)animation=264;
      else animation=shield?202:201;
    }
    actor.side=1;context.fieldE0=1;
  }
  if(record.reaction===12)record.reaction=animation===200||animation===263?206:207;
  else if(record.reaction===11)record.reaction=animation===202||animation===265?210:209;
  else if(record.reaction===14){
    const base=target?integer(required(p,'baseAnimation')(target),'defender base animation')&65535:0;
    if([5,7,8,6].includes(base))record.reaction=({5:217,7:218,8:8,6:6})[base];
    else if(!target||target.objectType!==5||(integer(required(p,'lockTarget')(target),'defender lock target')>>>0)===(actor.id>>>0))
      record.reaction=animation===202||animation===265?215:animation===200||animation===263?213:214;
    else record.reaction=directionalReaction(actor,target,p);
  }
  return animation;
}
function draw(p){const result=integer(required(p,'random')(),'CRT draw');if(result<0||result>32767)throw new Error('Native client animation random draw is out of range');return result;}

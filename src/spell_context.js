import {OBJECT_INVALID} from './game_object_array.js';
const integer=(o,key)=>{if(!Number.isInteger(o[key]))throw new Error(`Native spell context ${key} is unavailable`);return o[key]|0;};
// CNWSObject ctor14048bab9..14048bb24. +220 projectile time has no
// initializer here: its separate calculation owner must write it before use.
export function initializeSpellContext(o){
  if(o.objectType<5||o.objectType>14)return;
  o.nativeSpellPoint208??=[0,0,0];o.nativeSpellTarget214??=OBJECT_INVALID;o.nativeSpellId218??=-1;o.nativeSpellDomain21c??=0;
  o.nativeSpellImpact224??=0;o.nativeSpellSpontaneous228??=0;o.nativeSpellClass22c??=255;o.nativeSpellMetamagic22d??=255;
  o.nativeLastSpellCaster230??=OBJECT_INVALID;o.nativeLastSpell234??=-1;o.nativeLastSpellHarmful238??=0;o.nativeSpellFeat23c??=65535;
}
// ExecuteCommandGetSpellId140530610, GetSpellFeatId140530580 and
// GetSpellCastSpontaneously140530480 use AsNWSObject, not lastSpellId+184.
// ExecuteCommandGetSpellCast140530310 limits last-spell history to types5/9/10.
export function scriptSpellContext(o,command,{validObjectScript=1}={}){
  const world=o&&o.objectType>=5&&o.objectType<=14;
  const history=world&&[5,9,10].includes(o.objectType);
  switch(command){
    case 'GetSpellId':return world?integer(o,'nativeSpellId218'):-1;
    case 'GetSpellFeatId':return world?(integer(o,'nativeSpellFeat23c')<<16)>>16:-1;
    case 'GetSpellCastSpontaneously':return world?integer(o,'nativeSpellSpontaneous228'):0;
    case 'GetMetaMagicFeat':return world?integer(o,'nativeSpellMetamagic22d')&255:255;
    case 'GetSpellCasterItem':return o?.objectType===5?integer(o,'nativeSpellTarget818')>>>0:OBJECT_INVALID;
    case 'GetSpellTargetObject':return validObjectScript===1&&world&&[5,9].includes(o.objectType)?integer(o,'nativeSpellTarget214')>>>0:OBJECT_INVALID;
    case 'GetLastSpellCaster':return history?integer(o,'nativeLastSpellCaster230')>>>0:OBJECT_INVALID;
    case 'GetLastSpell':return history?integer(o,'nativeLastSpell234'):-1;
    case 'GetLastSpellHarmful':return history?integer(o,'nativeLastSpellHarmful238'):0;
    default:throw new Error(`Native spell context command ${command} is unavailable`);
  }
}
// ExecuteCommandGetSpellTargetLoc140530920 copies the stored cast point and
// the CASTER's raw orientation. Area comes from the target if it exists;
// only a failed target lookup falls back to the caster's area. Null target
// area does not fall back. Positions/orientations at this boundary are native.
export function spellTargetLocation(actor,p,{validObjectScript=1}={}){
  const empty=()=>({areaId:OBJECT_INVALID,position:[0,0,0],nativeOrientation:[0,0,0]});
  if(validObjectScript!==1||!actor||![5,9].includes(actor.objectType))return empty();
  if(typeof p?.object!=='function'||typeof p.area!=='function'||typeof p.orientation!=='function')throw new Error('Native spell target location providers are unavailable');
  const target=p.object(integer(actor,'nativeSpellTarget214')>>>0),area=p.area(target??actor),point=actor.nativeSpellPoint208,orientation=p.orientation(actor);
  if(![point,orientation].every(v=>Array.isArray(v)&&v.length===3&&v.every(Number.isFinite)))throw new Error('Native spell target location vectors are unavailable');
  return{areaId:area?area.id>>>0:OBJECT_INVALID,position:point.map(Math.fround),nativeOrientation:orientation.map(Math.fround)};
}

import {OBJECT_INVALID} from './game_object_array.js';
import {addTalentOnObject,addTalentAtLocation} from './talent_actions.js';
const integer=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native spell-like ${name} is unavailable`);return v|0;};

// Decoded input35,140454ba7..140454d3f, with shared controlled-actor8ac
// and packet overflow gates. The native branch returns0 even after dispatch;
// its result is not a claim that a cast was rejected or a slot consumed.
export async function receiveSpellLikeInput(client,p){
  const object=p.clientObject(client);let actor=object?p.asCreature(object):null;
  if(actor&&integer(actor.nativeField8ac,'creature field8ac')!==0)actor=null;
  const stats=actor?p.stats(actor):null;
  if(p.overflow()!==0)return 0;
  const spellId=p.readDword()>>>0,casterLevel=p.readByte()&255,flags=p.readByte()&255;
  const targetId=flags&1?p.readObjectId()>>>0:OBJECT_INVALID;
  const position=flags&2?[p.readFloat(),p.readFloat(),p.readFloat()].map(Math.fround):[0,0,0];
  if(p.overflow()!==0||p.underflow()!==0||!actor||!stats)return 0;
  if(!p.spell(spellId)){await p.feedback(actor,22);return 0;}
  await p.actionManager(actor,1);
  if(targetId!==OBJECT_INVALID)await p.onObject(actor,spellId,targetId,254,casterLevel,0);
  else await p.atLocation(actor,spellId,position,254,casterLevel,0);
  return 0;
}

// Spell branch0 of AddUseTalentOnObjectActions140380fb0 and
// AddUseTalentAtLocationActions140380e20, item sentinel/invalid property path.
// Other talent kinds and item use remain separate owners. Both wrappers ignore
// AddCastSpellActions' result and return1 after entering the enabled branch.
export async function addSpellTalentOnObject(actor,spellId,targetId,classIndex,casterLevel,metamagic,p){
  return addTalentOnObject(actor,0,spellId,targetId,classIndex,OBJECT_INVALID,-1,casterLevel,metamagic,p);
}
export async function addSpellTalentAtLocation(actor,spellId,point,classIndex,casterLevel,metamagic,p){
  return addTalentAtLocation(actor,0,spellId,point,classIndex,OBJECT_INVALID,-1,casterLevel,metamagic,p);
}

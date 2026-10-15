import {OBJECT_INVALID} from './game_object_array.js';

// HandlePlayerToServerInputMessage1404531b0, message18 at1404543xx..140454bcx.
// This is the decoded local request boundary, not an NWN network packet.
// Script ExecuteCommandCastSpell has different class-selection semantics.
export async function receiveSpellInput(actor,request,p){
  if(!actor||actor.objectType!==5)return 0;
  const {spellId,classIndex,domainLevel=0,metamagic=0,spontaneous=0,targetId=OBJECT_INVALID,position=[0,0,0],location=0,targetType}=request;
  if(![spellId,classIndex,domainLevel,metamagic,spontaneous,targetId,location,targetType].every(Number.isInteger))throw new Error('Player spell input fields are unavailable');
  if(!Array.isArray(position)||position.length!==3||!position.every(Number.isFinite))throw new Error('Player spell input position is unavailable');
  const spell=p.spell(spellId>>>0),reject=async()=>{await p.feedback(actor,22);return 0;};
  if(!spell||(targetType&65535)!==spell.targetType)return reject();
  // Conversion consumes another prepared spell, and has its own native owner.
  // Do not turn a requested spontaneous conversion into an ordinary cast.
  if(spontaneous!==0)throw new Error('Native player spontaneous conversion input is not implemented');
  const master=p.spell(spell.master);
  if(!master)return 0;
  if((metamagic&255)!==0&&(master.metamagic&metamagic&255)===0||
    (p.uses(actor,spellId>>>0,classIndex&255,domainLevel&255,metamagic&255)&255)===0)return reject();
  await p.actionManager(actor,1);
  return p.addCast(actor,{spellId:spellId>>>0,classIndex:classIndex&255,domainLevel:domainLevel&255,metamagic:metamagic&255,
    spontaneous:0,targetId:targetId>>>0,position:position.map(Math.fround),location:Number(location!==0)});
}

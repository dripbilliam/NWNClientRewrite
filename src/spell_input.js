import {OBJECT_INVALID} from './game_object_array.js';

// HandlePlayerToServerInputMessage1404531b0, message18.
// This is the decoded local request boundary, not an NWN network packet.
// Script ExecuteCommandCastSpell has different class-selection semantics.
export async function receiveSpellInput(actor,request,p){
  if(!actor||actor.objectType!==5)return 0;
  const {spellId,classIndex,domainLevel=0,metamagic=0,spontaneous=0,targetId=OBJECT_INVALID,position=[0,0,0],location=0,targetType}=request;
  if(![spellId,classIndex,domainLevel,metamagic,spontaneous,targetId,location,targetType].every(Number.isInteger))throw new Error('Player spell input fields are unavailable');
  if(!Array.isArray(position)||position.length!==3||!position.every(Number.isFinite))throw new Error('Player spell input position is unavailable');
  const spell=p.spell(spellId>>>0),reject=async()=>{await p.feedback(actor,22);return 0;};
  if(!spell||(targetType&65535)!==spell.targetType)return reject();
  let converted=spontaneous,available=false;
  if(converted!==0&&p.classAllowsConversion(actor,classIndex&255)){
    if((p.uses(actor,spellId>>>0,classIndex&255,domainLevel&255,metamagic&255)&255)!==0)converted=0;
    else{const base=domainLevel!==0?domainLevel&255:p.level(actor,spellId>>>0,classIndex&255)&255;
      available=p.slots(actor,classIndex&255,(base+p.metamagicCost(metamagic&255))&255).some(row=>row&&(row.ready&255)!==0&&row.domain===0);}
  }
  const master=p.spell(spell.master);
  if(!master)return 0;
  if((metamagic&255)!==0&&(master.metamagic&metamagic&255)===0||
    (converted!==0?!available:(p.uses(actor,spellId>>>0,classIndex&255,domainLevel&255,metamagic&255)&255)===0))return reject();
  await p.actionManager(actor,1);
  return p.addCast(actor,{spellId:spellId>>>0,classIndex:classIndex&255,domainLevel:domainLevel&255,metamagic:metamagic&255,
    spontaneous:converted,targetId:targetId>>>0,position:position.map(Math.fround),location:Number(location!==0)});
}

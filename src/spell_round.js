import {createRoundAction,addRoundAction} from './combat_action.js';
import {OBJECT_INVALID} from './game_object_array.js';

// StartCombatRoundCast14037a000. The started/paused flags are both set,
// while +2f1c is zero. Signed overlap/bleed subtraction stores a DWORD.
export function startSpellRound(round,length){
  if(!round||!Array.isArray(round.actions)||![length,round.overlap,round.bleed].every(Number.isInteger))
    throw new Error('Native spell combat round storage is unavailable');
  round.started=true;round.paused=true;round.timer=0;
  if((round.overlap|0)>0)round.length=(length-(round.overlap|0))>>>0;
  else if((round.overlap|0)===0&&(round.bleed|0)===0)round.length=length>>>0;
  else{
    const decrease=Math.min(round.bleed|0,1000);
    round.length=(length-decrease)>>>0;round.bleed=((round.bleed|0)-decrease)|0;
  }
  round.spellCastRound=false;round.pauseTimer=0;round.pausedBy=OBJECT_INVALID;
  round.actions.length=0;addRoundAction(round,createRoundAction(2));
}

// RemoveSpellAction140378f80 traverses the entire round list. It removes
// every BYTE type2, including future entries, and retains all other nodes.
export function removeSpellActions(round){
  if(!Array.isArray(round?.actions))throw new Error('Native spell round action list is unavailable');
  for(let i=0;i<round.actions.length;){
    if((round.actions[i].nativeActionType&255)===2)round.actions.splice(i,1);else i++;
  }
}

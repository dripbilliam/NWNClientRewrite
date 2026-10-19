import {OBJECT_INVALID} from './game_object_array.js';
// Client781e80 mask2000: update the existing master's companion278/familiar27c
// cells for native types2/3, then clear this creature's own cells from flags.
// No scan, name inference, ownership grant or backfill when the master is absent.
export function applyNetworkAssociateState(actor,state,lookup){
 if(state.master===undefined)return;
 const owner=lookup(state.master);
 if(owner?.objectType===5){if(state.field908===2)owner.companionId=actor.id;else if(state.field908===3)owner.familiarId=actor.id;}
 if(state.field910===0)actor.companionId=OBJECT_INVALID;if(state.field914===0)actor.familiarId=OBJECT_INVALID;
}
export function networkFamiliar(world,actor){const o=world?.registry.get(actor?.familiarId??OBJECT_INVALID);return o?.objectType===5&&!o.replicationRemoved?o:null;}

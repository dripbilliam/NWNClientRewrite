import {OBJECT_INVALID} from './game_object_array.js';

// Server constructor14055c5ca; GetFirstPCObject14055fc40 and
// GetNextPCObject140560cc0 share one cursor over the live client slots.
// They do not enumerate authored IsPC creatures in the object registry.
export class PlayerEnumeration{
  constructor(){this.index=0;}
  next(clients,objectId,first=false){
    this.index=first?0:(this.index+1)|0;
    while(this.index<clients.length){
      const client=clients[this.index];
      if(client){const id=objectId(client)>>>0;if(id!==OBJECT_INVALID)return id;}
      this.index=(this.index+1)|0;
    }
    return OBJECT_INVALID;
  }
}

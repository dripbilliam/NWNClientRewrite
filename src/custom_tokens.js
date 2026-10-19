const assigned=value=>{if(!(value instanceof Uint8Array))throw new Error('Native custom-token bytes are unavailable');return value[0]===0?new Uint8Array():Uint8Array.from(value);};
// CTlkTable::SetCustomToken14019a5d0: sorted physical records, signed-negative
// IDs ignored. Existing keys keep their record; inserting reallocates/copies.
export function setCustomToken(state,id,value){
 id|=0;if(id<0)return;let low=0,high=state.records.length;
 while(low<high){const middle=(low+high)>>>1,key=state.records[middle].id>>>0;if(key>(id>>>0))high=middle;else if(key<(id>>>0))low=middle+1;else{state.records[middle].bytes=assigned(value);return;}}
 const records=state.records.map(r=>({id:r.id,bytes:assigned(r.bytes)}));records.splice(low,0,{id,bytes:assigned(value)});state.records=records;
}
// Successful typed-pop body of command284140540570. This wrapper's pop
// failures unusually return-638. Reserved0..9 are protected here, not below.
export async function scriptSetCustomToken(id,value,p){
 id|=0;if(id<=9)return;await p.set(id,value);const clients=await p.players(),end=clients.length;
 for(let i=0;i<end;i++)if(await p.object(clients[i]))await p.send(clients[i],id,value);
}
// SendServerToPlayerSetCustomToken1404df990..4dfa5f. Create size uses original
// stored length; the owning string copy separately normalizes a leading NUL.
export async function writeSetCustomToken(message,playerId,id,value,p){
 if(!(value instanceof Uint8Array))throw new Error('Native custom-token message string is unavailable');
 await p.create(message,(value.length+8)>>>0,playerId>>>0,1);await p.writeInt(message,id|0,32);await p.writeString(message,assigned(value),32);return p.payload(message);
}
export async function sendSetCustomToken(message,playerId,id,value,p){
 const payload=await writeSetCustomToken(message,playerId,id,value,p);return payload.status?(await p.send(message,playerId>>>0,0x32,1,payload.data,payload.length))|0:0;
}

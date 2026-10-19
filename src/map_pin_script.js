// ExecuteCommandSetMapPinEnabled140543780..1405438aa after typed VM pops.
// Write the raw INT; send to every client with a game object, without the
// same-area filter used by CreateObject's Created notification.
export async function scriptSetMapPinEnabled([id,enabled],p){
 id>>>=0;enabled|=0;const waypoint=await p.waypoint(id);
 if(!waypoint||(waypoint.nativeMessageFields[0x308]|0)===0)return;
 waypoint.nativeMessageFields[0x30c]=enabled;
 const message=await p.message(),clients=await p.clients();
 for(const client of clients)if(await p.clientObject(client))await p.send(message,client,id,enabled);
}

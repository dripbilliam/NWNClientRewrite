const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native speech ${n} is unavailable`);return v|0;};
const f=Math.fround;
// ExecuteCommandSpeakStrRef140546970. The same wrapper handles immediate691
// and queued240. These five native exclusions are literal command guards.
export async function scriptSpeakStrRef(command,selfId,strRef,volume,p){
 strRef>>>=0;volume|=0;if(integer(p.active,'command mode')!==1)return;
 const found=await p.lookup(selfId>>>0);if((integer(found.status,'lookup status')&255)!==0)return;
 const channel=volume===1?10:volume===2?9:8,object=await p.asObject(found.object);
 if(!object||[0x24,0xcf90,0x9e33,0xbe3,0xbd8].includes(strRef))return;
 if((command|0)===240){const owner=await p.asObject(found.object);if(!owner)throw new Error('Native speech repeated object cast failed');
  if(integer(owner.nativeFieldEc,'commandable')===0)return;
  const target=await p.asObject(found.object);if(!target)throw new Error('Native speech queue object cast failed');await p.add(target,33,65535,[{type:1,value:strRef},{type:1,value:channel}]);
 }else await p.send(channel,selfId>>>0,strRef);
}
// Full queued action4a70e0 with profiling disabled; activity mutations retain
// their shared lower owners. Completion2 follows delivery regardless of result.
export async function executeSpeakStrRef(actor,node,p){
 if(await p.asCreature(actor)){const creature=await p.asCreature(actor);await p.activityManager(creature,2);await p.setActivity(await p.asCreature(actor),1,0);}
 await p.send((node.parameterData[1]|0)&255,actor.id>>>0,node.parameterData[0]>>>0);return 2;
}
// SendServerToPlayerChatStrRefMessage1404d3320. Radius uses native f32 order
// Y²+X²+Z². Return accumulation does NOT stop subsequent deliveries on failure.
// null client denotes native special recipient0xfffffff7 for shout.
export async function sendChatStrRef(channel,id,strRef,p){
 channel&=255;id>>>=0;strRef>>>=0;
 if(channel===9)return(await p.send(null,id,channel,strRef,0xfffffff7))&1;
 if(channel!==8&&channel!==10)return 0;
 const found=await p.lookup(id);if((integer(found.status,'lookup status')&255)!==0)return 1;
 if(!await p.asObject(found.object))return 1;
 const area=await p.area(await p.asObject(found.object)),point=(await p.asObject(found.object)).position.slice(),clients=await p.players(),end=clients.length;let result=1;
 for(let i=0;i<end;i++){const client=clients[i],viewer=await p.clientObject(client);if(!viewer||area!==await p.area(viewer))continue;
  const x=f(f(viewer.position[0])-f(point[0])),y=f(f(viewer.position[2])-f(point[2])),z=f(f(viewer.position[1])-f(point[1])),radius=channel===8?20:3;
  if(f(f(f(y*y)+f(x*x))+f(z*z))<=f(radius*radius))result=(result&(await p.send(client,id,channel,strRef)))|0;
 }return result;
}
// Protected packet writer4d4660. Transport header and PLAYER_ID are separate.
export async function writeChatStrRef(message,id,strRef,p){
 await p.create(message,8,0xffffffff,1);await p.writeObject(message,id>>>0);await p.writeDword(message,strRef>>>0,32);return p.payload(message);
}
export async function sendChatStrRefPacket(message,playerId,id,channel,strRef,p){
 const payload=await writeChatStrRef(message,id,strRef,p);return payload.status?(await p.send(message,playerId>>>0,9,channel&255,payload.data,payload.length))|0:0;
}

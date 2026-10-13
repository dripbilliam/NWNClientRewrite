const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native perception event ${n} is unavailable`);return v|0;};
const required=(p,name)=>{if(typeof p[name]!=='function')throw new Error(`Native perception event provider ${name} is unavailable`);return p[name];};
// Creature EventHandler event10 ScriptEvent type1,14038f47e..14038f569.
// Slots are Hear,See,Inaudible,Vanished, each an independent native int.
export async function receivePerceptionEvent(actor,payload,p){
  if((integer(payload?.type,'script event type')&65535)!==1)throw new Error('Native nonperception script event handler is unavailable');
  actor.nativeLastPerceived79c=integer(payload.objectIds?.[0]??0x7f000000,'perceived ID')>>>0;
  const code=integer(payload.integers?.[0]??0,'code');
  if(code===1){actor.nativePerceptionInaudible7a8=1;actor.nativePerceptionVanished7ac=0;actor.nativePerceptionHeard7a0=0;actor.nativePerceptionSeen7a4=0;}
  else if(code===0){actor.nativePerceptionHeard7a0=1;actor.nativePerceptionSeen7a4=0;actor.nativePerceptionInaudible7a8=0;actor.nativePerceptionVanished7ac=0;}
  else if(code===3){actor.nativePerceptionHeard7a0=0;actor.nativePerceptionSeen7a4=0;actor.nativePerceptionInaudible7a8=0;actor.nativePerceptionVanished7ac=1;}
  else if(code===2){actor.nativePerceptionHeard7a0=0;actor.nativePerceptionSeen7a4=1;actor.nativePerceptionInaudible7a8=0;actor.nativePerceptionVanished7ac=0;}
  const name=await required(p,'scriptName')(actor,1);
  if(typeof name!=='string')throw new Error('Native perception script name is unavailable');
  if(integer(await required(p,'pc')(actor),'PC result')!==0&&name==='default')return;
  await required(p,'runScript')(actor,1);
}

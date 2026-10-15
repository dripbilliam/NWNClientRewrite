const integer=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native attack input ${name} is unavailable`);return v|0;};
const required=(p,name)=>{if(typeof p[name]!=='function')throw new Error(`Native attack input provider ${name} is unavailable`);return p[name];};

// HandlePlayerToServerInputMessage1404531b0: decoded subtype2 branch,
//140453366..1404533e4. OBJECTID wire decoding remains a separate provider.
// Packet acceptance1 is independent of AddAttackActions' return value; the
// pending special queue clears AFTER that call, even when combat rejects it.
export async function receiveAttackInput(client,p){
  const object=required(p,'clientObject')(client);
  let actor=object?required(p,'asCreature')(object):null;
  if(actor&&integer(actor.nativeField8ac,'creature field8ac')!==0)actor=null;
  if(integer(required(p,'overflow')(),'entry overflow')!==0)return 0;
  const targetId=required(p,'readObjectId')();
  if(!Number.isInteger(targetId)||targetId<0||targetId>0xffffffff)throw new Error('Native attack input OBJECTID is unavailable');
  if(integer(required(p,'overflow')(),'target overflow')!==0||integer(required(p,'underflow')(),'target underflow')!==0||!actor)return 0;
  await required(p,'addAttack')(actor,targetId>>>0,0,1,0);
  await required(p,'clearSpecial')(actor.combatRound);
  return 1;
}

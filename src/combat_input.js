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

// Decoded subtype10 branch140453807..140453897. Native acceptance returns
// the requested BYTE, independently of ToggleMode's result (zero for mode0).
export async function receiveModeInput(client,p){
  const object=p.clientObject(client);let actor=object?p.asCreature(object):null;
  if(actor&&integer(actor.nativeField8ac,'creature field8ac')!==0)actor=null;
  if(p.overflow()!==0)return 0;
  const mode=integer(p.readByte(),'mode byte')&255;
  if(p.overflow()!==0)return 0;
  const targetId=mode===5?p.readObjectId():0x7f000000;
  if(p.overflow()!==0||p.underflow()!==0||!actor||integer(actor.nativeFieldEc,'commandability')===0)return 0;
  if(mode===5)await p.addCounter(actor,targetId>>>0);
  await p.toggle(actor,mode);
  return mode;
}

// Decoded subtype27 at140454288..140454331. Shared entry handling has
// already nullified field8ac actors. This branch has no commandability gate,
// rechecks ownership, and returns native0 even after delivering the command.
export async function receiveAssociateInput(client,p){
  const object=p.clientObject(client);let actor=object?p.asCreature(object):null;
  if(actor&&integer(actor.nativeField8ac,'creature field8ac')!==0)actor=null;
  let id=p.readObjectId()>>>0;const command=p.readInt()|0;
  if(p.overflow()!==0||p.underflow()!==0||!actor)return 0;
  if(command===-19&&id===actor.id)id=await p.associateId(actor,1,1);
  const target=p.creature(id);
  if(target&&(actor.id===target.masterId||actor.id===id&&command===-13))await p.receive(target,command);
  return 0;
}

// Decoded Input subtype30,140455376..14045541e. It resolves the packet's
// creature ID independently of the controlled actor, checks8ac/9f8, and removes
// only the first type62 ID group. No commandable/dead/feat gate is added here.
export async function receiveCancelPolymorphInput(_client,p){
 const id=p.readObjectId()>>>0;
 if(p.overflow()!==0)return 0;
 const actor=p.creature(id);if(!actor||integer(actor.nativeField8ac,'creature field8ac')!==0||integer(actor.nativeField9f8,'polymorph lock mode')!==0)return 0;
 const effect=p.effects(actor).find(e=>(e.type&65535)===62);if(effect)await p.remove(actor,effect.id);
 return 0;
}

// Input6,1404533e9..1404534f7. Native always passes a point pointer to
// UseFeat: zero XYZ for object targets, decoded XYZ for invalid/ground target.
// Packet acceptance1 is independent of UseFeat's return. No extra PC/dead or
// commandability gate is added to this decoded boundary.
export async function receiveFeatInput(client,p){
 const object=p.clientObject(client);let actor=object?p.asCreature(object):null;
 if(actor&&integer(actor.nativeField8ac,'creature field8ac')!==0)actor=null;
 if(p.overflow()!==0)return 0;
 const feat=p.readWord()&65535,auxiliary=p.readWord()&65535,target=p.readObjectId()>>>0;
 const point=target===0x7f000000?[p.readFloat(),p.readFloat(),p.readFloat()].map(Math.fround):[0,0,0];
 if(p.overflow()!==0||p.underflow()!==0||!actor)return 0;
 const area=p.area(actor);if(!area)return 0;
 await p.use(actor,feat,auxiliary,target,p.area(actor).id,point);
 return 1;
}

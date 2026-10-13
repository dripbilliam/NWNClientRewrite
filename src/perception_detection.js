import { subtractWorldTimes } from './reputation.js';
import { getBlind } from './perception.js';
import { normalizeOrientation } from './combat_lifecycle.js';
import { OBJECT_INVALID } from './game_object_array.js';
const f=Math.fround;
const signedByte=value=>(integer(value,'skill rank')<<24)>>24;
const byte=(actor,name)=>integer(actor[name],name)&255;
const real=(value,name)=>{if(!Number.isFinite(value))throw new Error(`Native perception ${name} is unavailable`);return f(value);};
const native=point=>{if(point?.length!==3||!point.every(Number.isFinite))throw new Error('Native perception position is unavailable');return[f(point[0]),f(-point[2]),f(point[1])];};
const render=point=>[point[0],point[2],f(-point[1])];
const lengthSquared=delta=>f(f(f(delta[1]*delta[1])+f(delta[0]*delta[0]))+f(delta[2]*delta[2]));
const normalize=point=>native(normalizeOrientation(render(point)));
function raisedDistance(actor,target){
  const from=native(actor.position),to=native(target.position);from[2]=f(from[2]+1);to[2]=f(to[2]+1);
  const delta=to.map((value,i)=>f(value-from[i]));return{from,to,delta,squared:lengthSquared(delta)};
}
export function animationStationary(animation){
  const value=integer(animation,'animation')&65535,offset=(value-78)&65535;
  return Number(((value-2)&65535)>2&&(offset>9||(0x3c3&(1<<(offset&31)))===0));
}
const stationary=actor=>animationStationary(actor.animationState);
const skill=async(p,actor,index,target)=>signedByte(await required(p,'skillRank')(actor,index,target,0));
async function detectingSkill(actor,target,index,p){
  const full=await detectMode(actor,p)===1||await detectMode(actor,p)===2;
  const rank=await skill(p,actor,index,target);return full?rank:Math.trunc(rank/2);
}
async function lightTypes(actor,p){
  const types=await required(p,'visualTypes')(actor);
  if(!Array.isArray(types))throw new Error('Native perception visual-effect cache is unavailable');
  return types.map(value=>integer(value,'visual-effect type')&65535);
}
// DoSpotDetection14038baa0. The skill calls are deliberately repeated;
// byte skill ranks, strict positive score and native f32 association matter.
export async function spotDetection(actor,target,retained,p){
  if(getBlind(actor)!==0||integer(retained,'retained flag')!==0)return 0;
  const {delta,squared}=raisedDistance(actor,target),combat=integer(actor.nativeField700,'combat flag');
  const range=real(combat===0?actor.nativeSightRange7b0:actor.nativeCombatSightRange7b4,'sight range');
  if(squared>f(range*range))return 0;
  const vision=byte(actor,'visionFlags');
  if(vision&4)return 1;
  if(vision&32){const radius=real(actor.blindSightRange,'blindsight range');if(f(radius*radius)>=squared)return 1;}
  const stealth=byte(target,'nativeField6ed');let score=0;
  if(stealth===1)score=-byte(target,'nativeHideRoll7c4')-await skill(p,target,5,actor);
  if(await skill(p,target,5,actor)===0||stealth===0)return 1;
  const rank=await detectingSkill(actor,target,17,p);
  const area=await required(p,'area')(actor);
  score=(score+integer(area.nativeSpotModifier21c,'area Spot modifier')+byte(actor,'nativeSpotRoll7c6')+rank)|0;
  if((integer(await required(p,'timeOfDay')(),'time of day')&255)===2){
    const types=await lightTypes(actor,p),light=type=>((type-153)&65535)<28;
    if(!types.some(type=>type===182||light(type)))score=(score-integer(await required(p,'rulesetInt')('SPOT_NO_LIGHT_MODIFIER',5),'unlit modifier'))|0;
    if((await lightTypes(target,p)).some(light))score=(score+integer(await required(p,'rulesetInt')('HIDING_LIGHT_MODIFIER',10),'hiding light modifier'))|0;
  }
  const client=await required(p,'client')(actor),targetClient=await required(p,'client')(target);
  if(client===null&&targetClient!==null){
    const direction=squared<=0?native(actor.orientation):normalize(delta),orientation=normalize(native(actor.orientation));
    const dot=f(f(f(direction[1]*orientation[1])+f(direction[0]*orientation[0]))+f(direction[2]*orientation[2]));
    if(dot<=f(-.707))score=(score-5)|0;
  }
  if(combat!==0)score=(score-10)|0;
  if(stationary(target))score=(score-5)|0;if(stationary(actor))score=(score+5)|0;
  const size=(integer(target.nativeSize718,'target size')-integer(actor.nativeSize718,'observer size'))|0;
  score=(score+({[-2]:-8,[-1]:-4,1:4,2:8}[size]??0))|0;
  score=(score+integer(await required(p,'favoredEnemyBonus')(actor,target),'favored enemy bonus'))|0;
  return Number(score>0);
}
// DoListenDetection14038aab0. ClearLineOfSight return values are ignored:
// both hit IDs/positions drive wall attenuation. The second object lookup
// intentionally uses the FIRST hit ID, as in the native instructions.
export async function listenDetection(actor,target,retained,p){
  if(integer(target.nativeSilence75c,'silence cache')!==0||(integer(actor.nativeField8d4,'perception flags')&16)===0)return 0;
  const {from,to,squared}=raisedDistance(actor,target);
  if(integer(retained,'retained flag')!==0||getBlind(actor)!==0){
    await required(p,'itemInSlot')(actor,16);
    let range=real(actor.nativeAttackRange71c,'attack range');
    const found=await required(p,'creature')(integer(target.id,'target ID')>>>0);
    if(found)range=f(range+real(found.nativePathInfo?.raw?.getFloat32(0x10,true),'target hit distance'));
    range=f(range+1.5);if(f(range*range)<squared)return 0;
    const flags=await required(p,'visibility')(actor,target.id);
    if(flags!==null&&(integer(flags,'visibility flags')&12)===4)return 0;
  }
  const combat=integer(actor.nativeField700,'combat flag'),range=real(combat===0?actor.nativeHearingRange7b8:actor.nativeCombatHearingRange7bc,'hearing range');
  if(f(range*range)<squared)return 0;
  const hitA=[0,0,0],hitB=[0,0,0],idA={id:OBJECT_INVALID},idB={id:OBJECT_INVALID};
  await required(p,'lineOfSight')(await required(p,'area')(actor),from.slice(),to.slice(),hitA,idA,OBJECT_INVALID,OBJECT_INVALID,0);
  await required(p,'lineOfSight')(await required(p,'area')(actor),to.slice(),from.slice(),hitB,idB,OBJECT_INVALID,OBJECT_INVALID,0);
  const a=integer(idA.id,'first hit ID')>>>0,b=integer(idB.id,'second hit ID')>>>0;let wallSquared;
  if(a===b&&a!==OBJECT_INVALID)wallSquared=f(.1600000113248825);
  else{
    if(a!==b){
      if(a!==OBJECT_INVALID){const o=await required(p,'object')(a);if(o)hitA.splice(0,3,...native(o.position));}
      if(b!==OBJECT_INVALID){const o=await required(p,'object')(a);if(o)hitB.splice(0,3,...native(o.position));}
    }
    wallSquared=lengthSquared(hitB.map((v,i)=>f(real(v,'wall hit')-real(hitA[i],'wall hit'))));
  }
  let score=0;
  if(wallSquared>0){
    const first=await required(p,'area')(actor);
    if((integer(first.flags,'area flags')&1)===0&&(integer((await required(p,'area')(actor)).flags,'area flags')&2)===0)score=Math.imul(Math.trunc(f(Math.sqrt(wallSquared))),-5);
    else{
      const area=await required(p,'area')(actor),path=area.nativeSoundPath288;
      if(!path?.raw)throw new Error('Native perception sound path is unavailable');
      const start=native(actor.position),goal=native(target.position);
      path.raw.setFloat32(0x64,start[0],true);path.raw.setFloat32(0x68,start[1],true);
      path.raw.setFloat32(0x4c,goal[0],true);path.raw.setFloat32(0x50,goal[1],true);
      if(integer(await required(p,'plotSoundPath')(await required(p,'area')(actor),path),'sound path result')!==1)return 0;score=-2;
    }
  }
  const rank=await skill(p,target,8,actor),stealth=byte(target,'nativeField6ed');
  if(rank===0||stealth===0||(integer(target.nativeStealthTarget8fc,'stealth target')>>>0)===(integer(actor.id,'observer ID')>>>0))return 1;
  if(stealth===1)score=(score-await skill(p,target,8,actor)-byte(target,'nativeMoveSilentlyRoll7c5'))|0;
  const listen=await detectingSkill(actor,target,6,p),area=await required(p,'area')(actor);
  score=(integer(area.nativeListenModifier220,'area Listen modifier')+byte(actor,'nativeListenRoll7c7')+score+listen)|0;
  if(combat!==0)score=(score-10)|0;
  if(stationary(target))score=(score-5)|0;if(stationary(actor))score=(score+5)|0;
  score=(score+Math.trunc(f(f(Math.sqrt(squared))/-3)))|0;
  score=(score+({1:-8,2:-4,4:4,5:8}[integer(target.nativeSize718,'target size')]??0))|0;
  score=(score+integer(await required(p,'favoredEnemyBonus')(actor,target),'favored enemy bonus'))|0;
  return Number(score>0);
}
const integer=(value,name)=>{if(!Number.isInteger(value))throw new Error(`Native perception ${name} is unavailable`);return value|0;};
const required=(p,name)=>{if(typeof p[name]!=='function')throw new Error(`Native perception provider ${name} is unavailable`);return p[name];};
// Creature constructor14037acb7..14037ad67 uses four CRT rand()%10+1
// calls, ordered MoveSilently, Hide, Spot, Listen. These are not RollDice.
export function initializePerceptionRolls(actor,random){
  if(typeof random?.next!=='function')throw new Error('Native perception constructor RNG is unavailable');
  actor.nativeDetectionDay56c??=0;actor.nativeDetectionTime570??=0;
  for(const name of ['nativeMoveSilentlyRoll7c5','nativeHideRoll7c4','nativeSpotRoll7c6','nativeListenRoll7c7']){
    const value=(integer(random.next(),'constructor random result')%10+1)&255;actor[name]??=value;
  }
}
// Full constructor RNG order includes heartbeat interval BEFORE these four
// cache rolls, then two rand()%100 AI counters AFTER them (seven draws).
export function initializeCreaturePerception(actor,random){
  if(typeof random?.next!=='function')throw new Error('Native creature constructor RNG is unavailable');
  const interval=integer(random.next(),'heartbeat interval random')%1200+6000;actor.nativeHeartbeatInterval554??=interval;
  initializePerceptionRolls(actor,random);
  const perception=integer(random.next(),'perception counter random')%100,heartbeat=integer(random.next(),'heartbeat counter random')%100;
  actor.nativePerceptionCounter580??=perception;actor.nativeHeartbeatCounter584??=heartbeat;
  for(const name of ['nativeHeartbeatDay54c','nativeHeartbeatTime550','nativePerceptionDay578','nativePerceptionTime57c','nativeSpawnState548'])actor[name]??=0;
}
// GetDetectMode140390490. Keen Senses240 forces mode1; otherwise idle
// animation0 implies mode2 unless the actual detect byte is exactly1.
export async function detectMode(actor,p){
  if(integer(await required(p,'hasFeat')(actor,240),'Keen Senses result')!==0)return 1;
  const value=integer(actor.nativeField6ec,'detect byte')&255;
  return integer(actor.animationState,'animation state')!==0||value===1?value:2;
}
// DoStealthDetection14038bfa0..14038c1a3. Refresh uses ONLY the world-time
// millisecond remainder, with inclusive6000 boundary. Listen runs first;
// Spot runs only for nonzero clear-line flag. Both output ints commit last.
export async function stealthDetection(actor,target,clear,out,retained,p){
  let seen=0,heard=0;
  if(target&&await required(p,'area')(target)===await required(p,'area')(actor)&&
     integer(await required(p,'dm')(actor),'DM result')===0){
    const now=await required(p,'worldTime')();
    const elapsed=subtractWorldTimes(now,{day:integer(actor.nativeDetectionDay56c,'detection day')>>>0,
      time:integer(actor.nativeDetectionTime570,'detection time')>>>0},p.dayLength);
    if(elapsed.status!==0)throw new Error('Native stealth-detection time subtraction left uninitialized output');
    if(elapsed.milliseconds>=6000){
      const roll=async sides=>integer(await required(p,'rollDice')(1,sides),'detection die')&255;
      if((integer(actor.nativeField6ed,'stealth byte')&255)===1){actor.nativeHideRoll7c4=await roll(20);actor.nativeMoveSilentlyRoll7c5=await roll(20);}
      const sides=await detectMode(actor,p)===1||await detectMode(actor,p)===2?20:10;
      actor.nativeSpotRoll7c6=await roll(sides);actor.nativeListenRoll7c7=await roll(sides);
      actor.nativeDetectionDay56c=integer(now.day,'current day')>>>0;actor.nativeDetectionTime570=integer(now.time,'current time')>>>0;
    }
    heard=integer(await required(p,'listen')(actor,target,retained),'Listen result');
    if(integer(clear,'clear-line flag')!==0)seen=integer(await required(p,'spot')(actor,target,retained),'Spot result');
  }
  out.heard=heard;out.seen=seen;return Number(seen!==0||heard!==0);
}
// DoPerceptionUpdateOnCreature14038b0c0. Visibility is persistent native
// state. Event1 denotes hear/see gain/loss (0/2,1/3), carried by AI event10.
export async function updateCreaturePerception(actor,target,force,p){
  const area=await required(p,'area')(actor);if(area===null||target.id===actor.id)return;
  force=integer(force,'force flag');
  if(force!==0&&integer(await required(p,'hasFeat')(target,433),'Hide in Plain Sight feat')===0)force=0;
  if(integer(await required(p,'dm')(actor),'observer DM')===0&&integer(await required(p,'dm')(target),'target DM')===1&&
      integer(target.nativeStatsFieldBC,'DM stats state')===0&&integer(target.nativeCollisionFlag788,'DM collision state')===0)return;
  const combat=integer(actor.nativeField700,'combat flag'),sight=real(combat===0?actor.nativeSightRange7b0:actor.nativeCombatSightRange7b4,'sight range'),
    hearing=real(combat===0?actor.nativeHearingRange7b8:actor.nativeCombatHearingRange7bc,'hearing range'),range=sight<hearing?hearing:sight;
  const {from,to,squared}=raisedDistance(actor,target);let clear=0,retained=0;
  if(await required(p,'area')(target)===area){
    if(squared<f(range*range))clear=Number(integer(await required(p,'lineOfSight')(area,from,to,[0,0,0],{id:0},actor.id,target.id,1),'LOS result')===1);
    const ids=await required(p,'invisibleCreatureIds')();if(!Array.isArray(ids))throw new Error('Native perception module invisible-creature list is unavailable');
    for(const id of ids){
      const subject=await required(p,'creature')(integer(id,'invisible creature ID')>>>0);
      if(subject&&await required(p,'area')(actor)!==null&&await required(p,'area')(subject)!==null){
        const observerArea=await required(p,'area')(actor),subjectArea=await required(p,'area')(subject);
        if(integer(observerArea.id,'observer area ID')===integer(subjectArea.id,'invisible creature area ID')){retained=1;break;}
      }
    }
    if(getBlind(actor)!==0)retained=1;
    else if(retained===1)retained=integer(await required(p,'invisible')(target,actor,0),'invisibility result')&1;
  }
  const list=actor.perception;if(!list?.node||!list?.add||!list?.remove)throw new Error('Native perception visibility list is unavailable');
  const event=async code=>required(p,'enqueue')(10,target.id,actor.id,0,{type:1,integers:[code],objectIds:[target.id]});
  const detect=async(clear,out)=>{await required(p,'stealthDetection')(actor,target,clear,out,retained);out.seen=integer(out.seen,'seen output');out.heard=integer(out.heard,'heard output');};
  let node=list.node(target.id),out={seen:0,heard:0},gained=0,commitLoss=false;
  if(node===null){
    await detect(clear,out);
    if(clear===0&&out.heard===0)return;
    gained=Number(out.seen!==0||out.heard!==0);
  }else{
    if(retained!==((node.flags>>>4)&1)){
      if(retained===1)await required(p,'clearHostileActions')(actor,target);
      node.flags=((retained<<4)|(node.flags&239))&255;
    }
    let old=node.flags,loss=0;out={seen:old&1,heard:(old>>>1)&1};
    if(clear===0){
      loss=old&1;if(loss)out.seen=0;
      await detect(0,out);
      if(out.heard!==0){gained=1;commitLoss=loss!==0;}else commitLoss=true;
    }else{
      if((old&3)!==3||force!==0){
        await detect(clear,out);old=node.flags;
        if((old&2)===0)gained=Number(out.heard!==0);
        if((old&1)===0&&out.seen!==0)gained=1;
        if(force!==0&&out.seen===0&&(old&1)!==0){await required(p,'clearHostileActions')(actor,target);old=node.flags;}
      }
      if((old&1)!==0&&retained!==0){loss=1;out.seen=0;}
      if((old&2)!==0&&integer(target.nativeSilence75c,'target silence')!==0){loss=1;out.heard=0;}
      if(force!==0&&out.seen===0&&out.heard===0)loss=1;
      commitLoss=retained!==0&&(old&3)!==0||loss!==0;
    }
    if(commitLoss){
      node=list.node(target.id);
      if(node!==null){
        if((node.flags&2)!==0&&out.heard===0)await event(1);
        if((node.flags&1)!==0&&out.seen===0)await event(3);
        const flags=((out.heard&1)<<1)|(out.seen&1);node.flags=(flags|(node.flags&252))&255;
        if(flags===0&&retained===0)list.remove(target.id);
      }
    }
  }
  if(gained===0)return;
  node=list.node(target.id);
  if(node===null){
    list.add(target.id,out.seen,out.heard,0,retained);
    if(out.heard!==0)await event(0);if(out.seen!==0)await event(2);
  }else{
    if((node.flags&1)===0&&out.seen!==0){node.flags|=1;await event(2);}
    if((node.flags&2)===0&&out.heard!==0){node.flags|=2;await event(0);}
  }
}
// UpdateVisibleList1403dba50: reverse cached entries first, then the
// persistent area X array. Existing nodes are never checked twice here.
export async function updateVisibleList(actor,p){
  const area=await required(p,'area')(actor);if(area===null)return;
  await required(p,'markPerceptionWork')();
  if(integer(await required(p,'dead')(actor),'dead result')===1&&integer(await required(p,'pc')(actor),'PC result')===0&&
      ((integer(actor.associateType,'associate type')&65535)!==3||integer(await required(p,'controlled')(actor),'control result')===0))return;
  const list=actor.perception;if(!Array.isArray(list?.nodes))throw new Error('Native visibility array is unavailable');
  for(let index=list.nodes.length-1;index>=0;index--){
    const id=list.nodes[index].id,target=await required(p,'creature')(id);
    if(target===null)list.remove(id);else await required(p,'updatePerception')(actor,target,0);
  }
  const combat=integer(actor.nativeField700,'combat flag'),spot=real(combat===0?actor.nativeSightRange7b0:actor.nativeCombatSightRange7b4,'sight range'),
    listen=real(combat===0?actor.nativeHearingRange7b8:actor.nativeCombatHearingRange7bc,'hearing range'),range=spot<=listen?listen:spot;
  const x=native(actor.position)[0],spatial=await required(p,'spatial')(area);
  if(!spatial?.firstByX||!Number.isInteger(spatial.count))throw new Error('Native visibility area X array is unavailable');
  let index=spatial.firstByX(f(x-range));if(index===null)return;
  for(;index<spatial.count;index++){
    const id=spatial.ids[index]>>>0;if(id===actor.id)continue;
    const target=await required(p,'creature')(id);if(target===null)continue;
    const to=native(target.position);if(f(x+range)<to[0])return;
    const from=native(actor.position),delta=to.map((value,i)=>f(value-from[i]));
    if(list.node(id)===null&&lengthSquared(delta)<=f(range*range))await required(p,'updatePerception')(actor,target,0);
  }
}

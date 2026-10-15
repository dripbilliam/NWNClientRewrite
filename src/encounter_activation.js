import {OBJECT_INVALID} from './game_object_array.js';
import {NativeIdList} from './native_id_list.js';
import {intEntry} from './combat_stats.js';
import {nativeFloatEntry} from './movement_rate.js';
const f=Math.fround;
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native encounter ${n} is unavailable`);return v|0;};
const float=(v,n)=>{if(typeof v!=='number')throw new Error(`Native encounter ${n} is unavailable`);return f(v);};
const required=(p,n)=>{if(typeof p?.[n]!=='function')throw new Error(`Native encounter provider ${n} is unavailable`);return p[n];};
const cvtt=v=>Number.isFinite(v)&&v>=-2147483648&&v<2147483648?Math.trunc(v):-2147483648;

// RemoveFromActiveCreatureCount14043e480. Return-to-pool is exactly1;
// normal death can exhaust an encounter and queues its script before reset.
export async function removeEncounterActiveCreature(o,cr,returnToPool,p){
  let count=integer(o.nativeEncounterSpawned340,'spawned count');if(count===0)return;
  const cost=()=>float(required(p,'points')(o,cr),'creature point cost');
  o.nativeEncounterActivePool3c8=f(float(o.nativeEncounterActivePool3c8,'active pool')-cost());
  count=(count-1)|0;o.nativeEncounterSpawned340=count;
  if(o.nativeEncounterActivePool3c8<0)o.nativeEncounterActivePool3c8=0;
  if(integer(returnToPool,'return-to-pool flag')===1){o.nativeEncounterPool3c4=f(cost()+float(o.nativeEncounterPool3c4,'remaining pool'));return;}
  if(count!==0)return;
  await required(p,'exhaustedEvent')(o);
  if(integer(o.nativeEncounterReset324,'reset flag')===1)o.nativeEncounterLastSpawn34c=await required(p,'worldTime')();
  for(const entry of o.nativeEncounterCreatures390){entry.visited=0;entry.used=0;}
  o.nativeEncounterActive320=0;o.nativeEncounterStarted354=0;
}

// This owner grows linearly by16 (14043fea4), unlike generic ID lists.
export class EncounterActivateList extends NativeIdList{
  constructor(){super();this.reserve(16);}
  append(id){if(!Number.isInteger(id)||id<0||id>0xffffffff)throw new Error('Native encounter activation ID is invalid');if(this.count===this.capacity)this.reserve(this.capacity+16);this.ids[this.count++]=id;}
  removeAll(id){let removed=0;for(let n=0;n<this.count;n++){if(this.ids[n]===id)removed++;else if(removed)this.ids[n-removed]=this.ids[n];}this.count-=removed;}
}

// CalculatePointsFromCR14043b220. Fractional minima are physical rows;
// integer0..50 uses the ctor's 1.5^n table. Preserve the return1 half-CR branch.
export function calculateEncounterPoints(o,cr,p){
  cr=float(cr,'CR');
  if(cr>0&&cr<1){
    const minima=o.nativeFractionalCR428;
    if(!Array.isArray(minima)||minima.length<4)throw new Error('Native encounter fractional CR storage is unavailable');
    if(cr>=minima[0])return 1;
    const exponent=cr>=minima[1]?-1:cr>=minima[2]?-2:cr>=minima[3]?-3:-4;
    return float(required(p,'pow')(1.5,exponent),'fractional points');
  }
  if(Number.isNaN(cr)||cr<0||cr>50)return float(required(p,'pow')(1.5,cr),'power points');
  return float(required(p,'pointTable')()[Math.trunc(cr)],'point table cell');
}

// Constructor140439e00 and authored instance ReadEncounterFromGff14043d1c0.
// Saved activation ID remapping and uninitialized ctor fields stay explicit.
export function initializeEncounter(o,entry,rules,p){
  if(entry.AreaList?.length)throw new Error('Native saved encounter activation ID import is unavailable');
  o.nativeEncounterActivate360??=new EncounterActivateList();
  o.nativeFractionalCR428=rules.fractionalcr?Array.from({length:5},(_,n)=>nativeFloatEntry(rules.fractionalcr,n,'Min').value):null;
  const bool=(name,initial)=>Number(((entry[name]??initial)&255)!==0);
  o.nativeEncounterActive320=bool('Active',1);o.nativeEncounterReset324=bool('Reset',0);o.nativeEncounterResetTime328=integer(entry.ResetTime??60,'reset time');
  o.nativeEncounterSpawnOption32c=integer(entry.SpawnOption??0,'spawn option');o.nativeEncounterDifficulty330=rules.encdifficulty?intEntry(rules.encdifficulty,entry.DifficultyIndex??-1,'VALUE').value:integer(entry.Difficulty??0,'difficulty');
  o.nativeEncounterDifficultyIndex334=integer(entry.DifficultyIndex??-1,'difficulty index');o.nativeEncounterRecommended338=integer(entry.RecCreatures??2,'recommended creatures');o.nativeEncounterMaximum33c=integer(entry.MaxCreatures??8,'maximum creatures');
  o.nativeEncounterSpawned340=integer(entry.NumberSpawned??0,'number spawned');o.nativeEncounterHeartbeat344={day:(entry.HeartbeatDay??0)>>>0,time:(entry.HeartbeatTime??0)>>>0};
  o.nativeEncounterLastSpawn34c={day:(entry.LastSpawnDay??0)>>>0,time:(entry.LastSpawnTime??0)>>>0};o.nativeEncounterStarted354=bool('Started',0);o.nativeEncounterCanSpawn36c=0;
  o.nativeEncounterRespawns3b0=integer(entry.Respawns??0,'respawns');o.nativeEncounterCurrentSpawns3b4=integer(entry.CurrentSpawns??0,'current spawns');
  o.nativeEncounterMinimumPoints3bc=0;o.nativeEncounterAreaPoints3c0=float(entry.AreaPoints??0,'area points');o.nativeEncounterPool3c4=0;o.nativeEncounterActivePool3c8=float(entry.SpawnPoolActive??0,'active pool');
  o.nativeEncounterLastEntered3cc=(entry.LastEntered??OBJECT_INVALID)>>>0;o.nativeEncounterLastLeft3d0=(entry.LastLeft??OBJECT_INVALID)>>>0;o.nativeEncounterPlayerOnly434=bool('PlayerOnly',0);
  o.factionId=(entry.Faction??1)>>>0;
  if(o.geometry?.length){const xs=o.geometry.map(v=>v[0]),ys=o.geometry.map(v=>v[1]);o.nativeEncounterBounds={minX:f(Math.min(...xs)),maxX:f(Math.max(...xs)),minY:f(Math.min(...ys)),maxY:f(Math.max(...ys))};}
  o.nativeEncounterCreatures390=(entry.CreatureList??[]).map(e=>({resRef:String(e.ResRef??'').split('\0')[0].slice(0,16),cr:float(e.CR??0,'creature CR'),points:calculateEncounterPoints(o,e.CR??0,p),used:0,visited:0,single:boolEntry(e.SingleSpawn)}));
  // LoadEncounter14043c53b..14043c6b0 bubbles descending CR, preserving
  // equal order, then takes the final physical entry's point cost.
  const entries=o.nativeEncounterCreatures390;for(let pass=0;pass<entries.length;pass++)for(let n=0;n+1<entries.length;n++)if(entries[n+1].cr>entries[n].cr)[entries[n],entries[n+1]]=[entries[n+1],entries[n]];
  if(entries.length)o.nativeEncounterMinimumPoints3bc=entries.at(-1).points;
  o.nativeEncounterSpawnPoints3a0=(entry.SpawnPointList??[]).map(e=>({point:[float(e.X??0,'spawn X'),float(e.Y??0,'spawn Y'),float(e.Z??0,'spawn Z')],orientation:float(e.Orientation??0,'spawn orientation')}));
}
const boolEntry=v=>Number(((v??0)&255)!==0);

// UpdateActivateAreaList14043fbf0: remove all duplicate stale-position entries,
// increment index after compaction (thus skip the newly shifted entry), then
// X-sorted canonical scan. Missing IDs remain in the list, as in native code.
export async function updateEncounterActivation(o,enterer,p){
  enterer=integer(enterer,'enterer ID')>>>0;const area=required(p,'area')(o);if(!area)return;
  const list=o.nativeEncounterActivate360;if(!(list instanceof EncounterActivateList))throw new Error('Native encounter activation list is unavailable');
  for(let n=0;n<list.count;n++){const actor=required(p,'creature')(list.ids[n]);if(actor&&await required(p,'inside')(o,required(p,'position')(actor))===0)list.removeAll(list.ids[n]);}
  const bounds=o.nativeEncounterBounds;if(!bounds)throw new Error('Native encounter geometry bounds are unavailable');
  const first=required(p,'firstByX')(area,bounds.minX);if(first===null)return;
  for(let n=first;n<required(p,'spatialIds')(area).length;n++){
    const id=p.spatialIds(area)[n],actor=p.creature(id);if(!actor)continue;const point=p.position(actor);
    if(point[0]>bounds.maxX)break;
    if(await required(p,'reaction')(actor,o.id)!==2||await required(p,'dead')(actor)!==0||await required(p,'dying')(actor)!==0)continue;
    if(id!==enterer&&(point[1]<bounds.minY||point[1]>bounds.maxY||await p.inside(o,point)===0))continue;
    if(list.indexOf(id)<0)list.append(id);
    if(integer(o.nativeEncounterPlayerOnly434,'player-only')===0||integer(required(p,'statsPC')(actor),'stats PC')!==0)o.nativeEncounterCanSpawn36c=1;
  }
}

// TallyEnemyRadiusPoints14043f8b0: fixed30-unit X/Y rectangle, not a circle.
export async function tallyEncounterEnemyPoints(o,p){
  const area=required(p,'area')(o);if(!area)return;o.nativeEncounterAreaPoints3c0=0;
  const entered=required(p,'creature')(integer(o.nativeEncounterLastEntered3cc,'last entered')>>>0);if(!entered)return;
  const origin=required(p,'position')(entered),first=required(p,'firstByX')(area,f(origin[0]-30));if(first===null)return;
  const official=integer(await required(p,'officialCampaign')(),'campaign classification')&255;
  for(let n=first;n<required(p,'spatialIds')(area).length;n++){
    const actor=p.creature(p.spatialIds(area)[n]);if(!actor)continue;const point=p.position(actor);if(point[0]>f(origin[0]+30))break;
    if(await required(p,'reaction')(actor,o.id)!==2||await required(p,'dead')(actor)===1||await required(p,'dying')(actor)===1)continue;
    if(integer(required(p,'statsPC')(actor),'stats PC')===0){
      if((integer(actor.associateType,'associate type')&65535)===0)continue;
      const master=p.creature(integer(actor.masterId,'master ID')>>>0);if(master&&p.statsPC(master)===0)continue;
    }
    if(point[1]<f(origin[1]-30)||point[1]>f(origin[1]+30))continue;
    let level;
    if(official===1){
      level=0;const classes=required(p,'classes')(actor);if(!Array.isArray(classes)||classes.length>255)throw new Error('Native encounter class slots are unavailable');
      for(const slot of classes){const id=integer(slot.id,'class ID')&255,info=required(p,'classInfo')(id);if(!info)continue;const n=integer(slot.level,'class level')&255;
        level=(level+(((n-2)&255)<39?integer(info.effective[n],'effective CR')&255:n))|0;}
      if(integer(actor.nativeField89c,'creature PC')===0&&await required(p,'possessed')(actor)===0)level=Math.trunc(level/2);
    }else level=integer(required(p,'potentialLevel')(actor),'potential level')&255;
    o.nativeEncounterAreaPoints3c0=f(calculateEncounterPoints(o,f(level),p)+float(o.nativeEncounterAreaPoints3c0,'area points'));
  }
}

// Shared calculation in CalculateSpawnPool14043b2d0 and SpawnIfAppropriate.
async function addEncounterPool(o,cr,p){
  cr=float(cr,'pool CR');if(cr===-1)await tallyEncounterEnemyPoints(o,p);else o.nativeEncounterAreaPoints3c0=calculateEncounterPoints(o,cr,p);
  const points=float(o.nativeEncounterAreaPoints3c0,'area points');if(points===0)return;
  const score=(integer(o.nativeEncounterDifficulty330,'difficulty')+cvtt(required(p,'log')(points*.25)/p.log(1.5)+.5))|0;o.nativeEncounterScore3ac=score;
  let pool=calculateEncounterPoints(o,f((score-1)|0),p);
  if(integer(await required(p,'alwaysReset')(),'always-reset option')===0)pool=f(pool+float(o.nativeEncounterPool3c4,'spawn pool'));
  o.nativeEncounterPool3c4=pool;
}
export async function calculateEncounterPool(o,cr,p){await addEncounterPool(o,cr,p);}
export async function spawnEncounterIfAppropriate(o,enterer,cr,p){
  if(integer(o.nativeEncounterActive320,'active flag')===0||integer(o.nativeEncounterStarted354,'started flag')===1)return;
  o.nativeEncounterCanSpawn36c=0;await updateEncounterActivation(o,enterer,p);if(o.nativeEncounterCanSpawn36c!==1)return;
  await addEncounterPool(o,cr,p);if(float(o.nativeEncounterPool3c4,'spawn pool')>0){await required(p,'spawn')(o);o.nativeEncounterStarted354=1;}
}

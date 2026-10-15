const f=Math.fround;
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native encounter spawn ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p?.[n]!=='function')throw new Error(`Native encounter spawn provider ${n} is unavailable`);return p[n];};
const point=(v,n)=>{if(!Array.isArray(v)||v.length!==3||!v.every(Number.isFinite))throw new Error(`Native encounter spawn ${n} is unavailable`);return v.map(f);};
const distance=(a,b)=>{const d=a.map((v,n)=>f(v-b[n]));return f(f(f(d[0]*d[0])+f(d[1]*d[1]))+f(d[2]*d[2]));};

// SpawnEncounterCreatures14043f000: list preparation, farthest authored
// spawn point, canonical ctor/template load, safe/nonvisible placement,
// AddToArea/AI/orientation and separate alive-point/count/pool updates.
export async function spawnEncounterCreatures(o,p){
  const area=required(p,'area')(o);if(!area)return;
  if(integer(o.nativeEncounterMaximum33c,'maximum creature allocation')<0)throw new Error('Native encounter negative spawn allocation is unavailable');
  const out=[];await required(p,'makeList')(o,out);
  const recommended=()=>((integer(o.nativeEncounterRecommended338,'recommended')-integer(o.nativeEncounterSpawned340,'spawned'))|0);
  if(out.length<recommended()&&f(o.nativeEncounterPool3c4)>f(o.nativeEncounterMinimumPoints3bc))
    for(let n=out.length-1;n>=0;n--){if(out.length>=recommended())break;await required(p,'splitEntry')(o,out,n,{...out[n]});}
  if(out.length<recommended())await required(p,'padList')(o,out);
  if(f(o.nativeEncounterPool3c4)<f(o.nativeEncounterMinimumPoints3bc))o.nativeEncounterPool3c4=0;
  if(!out.length)return;
  const spawnPoints=o.nativeEncounterSpawnPoints3a0;if(!Array.isArray(spawnPoints))throw new Error('Native encounter spawn point storage is unavailable');
  const usesSpawnPoint=spawnPoints.length>0;let origin=[0,0,0],orientation=[1,0,0];
  if(usesSpawnPoint){
    const entered=required(p,'creature')(integer(o.nativeEncounterLastEntered3cc,'last entered')>>>0);
    if(entered){const at=point(required(p,'position')(entered),'enterer position');let farthest=0,index=0;
      for(let n=0;n<spawnPoints.length;n++){const d=distance(point(spawnPoints[n].point,'authored point'),at);if(d>farthest){farthest=d;index=n;}}
      const selected=spawnPoints[index];origin=point(selected.point,'selected point');const angle=f(f(Math.PI/2)-f(selected.orientation));
      // Original normalizes this bearing vector into a temporary, but later
      // SetOrientation14043f679 receives the unchanged initial [1,0,0].
      point(required(p,'normalize')([required(p,'cos')(angle),required(p,'sin')(angle),0]),'temporary bearing orientation');
    }
  }
  let fallbackLatched=false;
  for(const entry of out){
    const actor=await required(p,'construct')(o);if(!actor)throw new Error('Native encounter dereferences an unavailable creature constructor result');
    if(await required(p,'loadTemplate')(actor,entry.resRef)===0){required(p,'warning')('Native encounter invalid creature template');await required(p,'destroy')(actor);continue;}
    actor.nativeField948=o.id>>>0;actor.nativeField89c=0;
    let wasSafe=false,chosen=[0,0,0];
    if(usesSpawnPoint){
      const safe={point:[0,0,0]};if(await required(p,'safeLocation')(area,origin,20,actor.nativePathInfo,0,safe)===1){chosen=point(safe.point,'safe point');chosen[2]=f(await required(p,'height')(area,chosen));wasSafe=true;}
      else fallbackLatched=true;
    }
    if(!usesSpawnPoint||!wasSafe||fallbackLatched){
      const hidden={point:[0,0,0]},result=await required(p,'nonVisibleLocation')(area,point(required(p,'position')(o),'encounter origin'),actor.nativePathInfo,0,hidden,40);
      const value=point(hidden.point,'nonvisible output');
      if(result!==1&&value.every(v=>v===-1)){if(!wasSafe){await p.destroy(actor);continue;}}
      else{chosen=value;chosen[2]=f(await p.height(area,chosen));}
    }
    await required(p,'addToArea')(actor,area,chosen,0,1);
    await required(p,'setAILevel')(actor,Number(integer(required(p,'playerCount')(area),'area player count')>=1));
    if(usesSpawnPoint)await required(p,'setOrientation')(actor,orientation);
    o.nativeEncounterSpawned340=(integer(o.nativeEncounterSpawned340,'spawn count')+1)|0;
    o.nativeEncounterActivePool3c8=f(f(entry.points)+f(o.nativeEncounterActivePool3c8));
    o.nativeEncounterPool3c4=f(f(o.nativeEncounterPool3c4)-f(entry.points));if(o.nativeEncounterPool3c4<0)o.nativeEncounterPool3c4=0;
  }
}

const f=Math.fround;
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native encounter spawn list ${n} is unavailable`);return v|0;};
const float=(v,n)=>{if(typeof v!=='number')throw new Error(`Native encounter spawn list ${n} is unavailable`);return f(v);};
const required=(p,n)=>{if(typeof p?.[n]!=='function')throw new Error(`Native encounter spawn list provider ${n} is unavailable`);return p[n];};
const entries=o=>{if(!Array.isArray(o.nativeEncounterCreatures390))throw new Error('Native encounter physical creature list is unavailable');return o.nativeEncounterCreatures390;};
const append=(out,e)=>out.push({resRef:e.resRef,cr:e.cr,points:e.points,used:0,visited:0,single:0});
const maximum=o=>(integer(o.nativeEncounterMaximum33c,'maximum')-integer(o.nativeEncounterSpawned340,'spawned'))|0;
const recommended=o=>(integer(o.nativeEncounterRecommended338,'recommended')-integer(o.nativeEncounterSpawned340,'spawned'))|0;
const draw=(p,n)=>{const v=integer(required(p,'random')(),'CRT draw');if(v<0||v>32767)throw new Error('Native encounter CRT draw is outside its range');return v%n;};
const budget=n=>{if(n>10000)throw new Error('Native encounter selection exceeded the replacement action budget');};

// MakeSpawnList14043cc00. Fixed initial tolerance, descending physical CR
// groups, separate Used1c/Visited20 flags; grouped single count starts at1
// regardless of the FIRST entry's SingleSpawn flag (original quirk).
export function makeEncounterSpawnList(o,out,p){
  const list=entries(o);let pool=f(float(o.nativeEncounterPool3c4,'pool')-float(o.nativeEncounterActivePool3c8,'active pool'));
  const tolerance=f(pool/10);let iterations=0;
  for(let n=0;n<list.length;n++){
    if(out.length>=maximum(o)||!(pool>0))return;
    const e=list[n];if(e.cr===0||e.points>f(pool+tolerance))continue;
    if(n+1<list.length&&list[n+1].cr===e.cr){
      let next=n+1,count=1,singles=1,visited=0;list[n].visited=0;
      while(next<list.length&&list[next].cr===e.cr){list[next].visited=0;if(list[next].single!==0)singles++;count++;next++;}
      let last=next===list.length?next:next-1;const cost=list[last-1].points;
      if(f(pool+tolerance)>=cost){
        while(out.length<maximum(o)){
          budget(++iterations);const selected=list[n+draw(p,count)];
          if(selected.single===0||selected.used===0){append(out,selected);selected.used=1;pool=f(pool-selected.points);}
          if(selected.visited===0){selected.visited=1;visited++;}
          if(count===singles&&visited===count||!(f(pool+tolerance)>=cost))break;
        }
        n=last;
      }
    }else{
      do{
        if(out.length>=maximum(o)||e.single!==0&&e.used!==0)break;
        append(out,e);e.used=1;pool=f(pool-e.points);
      }while(f(pool+tolerance)>=e.points);
    }
  }
}

// PadOutCreatureCount14043cf90. Searches upward from the cheapest positive
// point cost; importantly it does NOT set Used1c on padding appends.
export function padEncounterSpawnCount(o,out,p){
  const list=entries(o);let remaining=(recommended(o)-out.length)|0,found=false,cost=0,iterations=0;
  while(remaining>0){
    for(let n=list.length-1;n>=0;n--)if(list[n].points>cost&&(list[n].single===0||list[n].used===0)){found=true;cost=list[n].points;break;}
    if(!found)return;
    let first=-1,last=0,singles=0,visited=0;
    for(let n=0;n<list.length;n++)if(list[n].points===cost){list[n].visited=0;if(first<0)first=n;last=n;if(list[n].single===1)singles++;}
    const count=last-first+1;if(first<0)throw new Error('Native encounter padding has no selected cost group');
    while(true){
      budget(++iterations);const e=list[first+draw(p,count)];
      if(e.single===0||e.used===0){append(out,e);remaining--;}
      if(e.visited===0){visited++;e.visited=1;}
      if(count===singles&&visited===singles)break;
      if(remaining<1)return;
    }
  }
}

// AddCreaturesToSpawnList14043adf0. Replaces a chosen entry by cheaper ones;
// count==1 clears the list, recommendation uses strict >, max is absolute.
export function splitEncounterSpawnEntry(o,out,index,entry,p){
  let pool=float(required(p,'points')(o,entry.cr),'split points');if(pool===float(o.nativeEncounterMinimumPoints3bc,'minimum points'))return;
  if(out.length===1)out.length=0;else if(index>=0&&index<out.length)out.splice(index,1);
  const cutoff=f(pool-f(.001)),list=entries(o);
  for(const e of list){
    if(out.length>recommended(o))return;
    if(pool<e.points)continue;
    while(e.points<=pool){
      if(cutoff<e.points||out.length>=integer(o.nativeEncounterMaximum33c,'maximum')||e.single!==0&&e.used!==0)break;
      append(out,e);e.used=1;pool=f(pool-e.points);
    }
  }
}

// List preparation and zero-pool tail from SpawnEncounterCreatures14043f000.
export function prepareEncounterSpawnList(o,p){
  const out=[];makeEncounterSpawnList(o,out,p);
  if(out.length<recommended(o)&&float(o.nativeEncounterPool3c4,'pool')>float(o.nativeEncounterMinimumPoints3bc,'minimum points'))
    for(let n=out.length-1;n>=0;n--){if(out.length>=recommended(o))break;splitEncounterSpawnEntry(o,out,n,{...out[n]},p);}
  if(out.length<recommended(o))padEncounterSpawnCount(o,out,p);
  if(float(o.nativeEncounterPool3c4,'pool')<float(o.nativeEncounterMinimumPoints3bc,'minimum points'))o.nativeEncounterPool3c4=0;
  return out;
}

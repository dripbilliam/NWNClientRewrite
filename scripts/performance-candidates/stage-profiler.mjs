// Diagnostic build only. Times are synchronous CPU/driver waits, not GPU time.
// Nested stages are inclusive and must not be added to their enclosing stage.
export function installStageProfiler({particles,shadowTraversal,now=()=>performance.now()}) {
  const restores=[],pending={};let last={};
  function wrap(owner,key,label) {
    if(!owner||typeof owner[key]!=='function')return;
    const original=owner[key];
    function measured(...args) {
      const start=now();
      try{const result=original.apply(this,args);if(label==='shadowInputs'){const row=pending.shadowInputResults??={calls:0,volatile:0,reused:0,shortCircuited:0};row.calls++;row.volatile+=Number(Boolean(result?.volatile));row.reused+=Number(Boolean(result?.reuse));row.shortCircuited+=Number(result?.inputs===null);}return result;}
      finally{const elapsed=now()-start,row=pending[label]??={calls:0,totalMs:0,maxMs:0};row.calls++;row.totalMs+=elapsed;row.maxMs=Math.max(row.maxMs,elapsed);}
    }
    owner[key]=measured;restores.push(()=>{if(owner[key]===measured)owner[key]=original;});
  }
  wrap(particles,'update','particleRuntime');
  wrap(shadowTraversal,'render','shadowTotal');
  wrap(shadowTraversal,'original','shadowSubmission');
  wrap(shadowTraversal?.cache,'plan','shadowInputs');
  wrap(shadowTraversal?.instances,'list','shadowGrouping');
  return {
    finishFrame(){last={};for(const key of Object.keys(pending)){last[key]={...pending[key]};delete pending[key];}return last;},
    snapshot(){return Object.fromEntries(Object.entries(last).map(([key,row])=>[key,{...row}]));},
    dispose(){for(const restore of restores.reverse())restore();restores.length=0;for(const key of Object.keys(pending))delete pending[key];last={};},
  };
}

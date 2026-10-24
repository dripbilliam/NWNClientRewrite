// Injected only by the queued probe, never by production. RAF gaps measure
// renderer responsiveness; they are not GPU query times or per-frame CPU work.
export function installFrameObserver() {
  if(window.__performanceQueueFrames)throw Error('Frame observer already installed');
  let active=false,label=null,rows=[],dropped=0,last=0,started=0,handle;
  const tick=()=>{const now=performance.now();if(active){if(rows.length<80000)rows.push({at:now,gapMs:now-last});else dropped++;last=now;}handle=requestAnimationFrame(tick);};
  window.__performanceQueueFrames={
    begin(value){active=true;label=value;rows=[];dropped=0;last=started=performance.now();},
    take(){active=false;return {label,rows,dropped,durationMs:performance.now()-started};},
    close(){active=false;cancelAnimationFrame(handle);delete window.__performanceQueueFrames;},
  };
  handle=requestAnimationFrame(tick);
}

export function frameMetrics(observation) {
  if(!observation||observation.dropped||!observation.rows?.length)return {complete:false,frames:observation?.rows?.length??0,dropped:observation?.dropped??0};
  const gaps=observation.rows.map(row=>row.gapMs);
  if(gaps.some(ms=>!Number.isFinite(ms)||ms<=0))throw Error('Invalid RAF frame gap');
  const sorted=gaps.slice().sort((a,b)=>a-b),total=gaps.reduce((a,b)=>a+b,0),fps=gaps.length*1000/total,p95Ms=sorted[Math.ceil(sorted.length*.95)-1],maxMs=sorted.at(-1);
  return {complete:true,frames:gaps.length,observedMs:total,fps,averageMs:total/gaps.length,p95Ms,maxMs,hitchesOver50Ms:gaps.filter(ms=>ms>50).length,freezesOver1000Ms:gaps.filter(ms=>ms>1000).length,
    sampledLocalTargetMet:gaps.length>=120&&fps>=60&&p95Ms<=16.7&&maxMs<1000};
}

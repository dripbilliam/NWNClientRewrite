import {frameMetrics} from './frame-observer.mjs';
import {previewComparisonModes as modes,previewComparisonPairs as pairs} from './preview-comparison-transform.mjs';
const check=(condition,message)=>{if(!condition)throw Error(message);};
const mean=values=>values.reduce((a,b)=>a+b,0)/values.length;
const median=values=>{const sorted=values.slice().sort((a,b)=>a-b),n=sorted.length;return n%2?sorted[(n-1)/2]:(sorted[n/2-1]+sorted[n/2])/2;};
export function summarizePreviewComparison(areas) {
  check(areas?.length===modes.length,'Expected twelve completed comparison visits');
  const phases=areas.map((area,index)=>{
    const audit=area.previewAudit,sample=area.samples?.at(-1),view=sample?.frame?.viewport,metrics=frameMetrics(area.frames);
    check(area.pass===index&&area.omitPreviews===modes[index],'Comparison mode/order mismatch');
    check(typeof area.resRef==='string'&&area.resRef.length>0,'Missing area identity');
    check(Number.isFinite(area.loadMs)&&area.loadMs>0,'Invalid area load duration');
    check(metrics.complete&&metrics.frames>=120,'Incomplete or too short frame observation');
    check(view?.bufferWidth===3440&&view?.bufferHeight===1369&&view?.pixelRatio===1,'Comparison render size differs');
    check(sample?.shadowBudget?.native?.maximum===1,'Comparison native shadow setting differs');
    check(sample.scene?.controlled?.rendered&&sample.scene?.objects>=100&&area.movingActors>=10,'Comparison crowd/player fixture incomplete');
    check(audit?.omit===modes[index]&&audit.rootPresent&&!audit.previewChecked,'Preview state differs from requested mode');
    check(!audit.persistentModelPreparation&&!audit.mainBatches&&!audit.matrixSubtrees,'Another experimental mode is enabled');
    check(audit.failedEmitters===0&&audit.emitters>0,'Native emitters unavailable in comparison');
    check(modes[index]?audit.previews===0&&audit.previewSprites===0:audit.previews>0&&audit.previewSprites>0,'Preview opt-out was not exercised');
    const telemetry=area.samples.map(row=>row.frame).filter(Boolean),average=key=>mean(telemetry.map(row=>row[key]));
    return {pass:index,omit:modes[index],resRef:area.resRef,loadMs:area.loadMs,...metrics,
      sampledWorkMs:average('totalMs'),sampledRenderMs:average('renderMs'),sampledCameraMs:average('cameraAndShadowsMs'),sampledParticlesMs:average('particlesMs'),
      objects:sample.scene.objects,nodes:audit.nodes,previews:audit.previews,previewSprites:audit.previewSprites,
      nonPreviewNodes:audit.nodes-audit.previews-audit.previewSprites,emitters:audit.emitters,draws:median(telemetry.map(row=>row.draw.calls))};
  });
  const comparisons=pairs.map(([before,candidate,after])=>{
    const a=phases[before],b=phases[candidate],c=phases[after];
    check(a.resRef===b.resRef&&b.resRef===c.resRef,'Matched visits refer to different areas');
    const baseline={fps:mean([a.fps,c.fps]),loadMs:mean([a.loadMs,c.loadMs]),p95Ms:mean([a.p95Ms,c.p95Ms])},warnings=[];
    for(const field of ['objects','nonPreviewNodes','emitters'])if(a[field]!==b[field]||b[field]!==c[field])warnings.push('Native scene '+field+' differs across neighbors');
    const baselineFpsSpreadPercent=(Math.max(a.fps,c.fps)/Math.min(a.fps,c.fps)-1)*100;
    if(baselineFpsSpreadPercent>5)warnings.push('Neighbor baseline FPS differs by more than 5%');
    return {before,candidate,after,resRef:b.resRef,baseline,candidateFps:b.fps,candidateLoadMs:b.loadMs,
      fpsChangePercent:(b.fps/baseline.fps-1)*100,loadChangePercent:(b.loadMs/baseline.loadMs-1)*100,
      p95ChangePercent:(b.p95Ms/baseline.p95Ms-1)*100,baselineFpsSpreadPercent,warnings};
  });
  return {scope:'Same-client preview opt-out; four warmup visits then four candidate visits matched to same-area baseline neighbors. RAF responsiveness, sampled CPU telemetry and moving NPC caveats apply.',
    warmupPasses:[0,1,2,3],phases,comparisons,medianFpsChangePercent:median(comparisons.map(row=>row.fpsChangePercent)),
    medianLoadChangePercent:median(comparisons.map(row=>row.loadChangePercent)),enableByDefault:false,goalComplete:false};
}

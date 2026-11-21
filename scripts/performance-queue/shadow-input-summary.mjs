import {frameMetrics} from './frame-observer.mjs';
import {previewComparisonModes as modes,previewComparisonPairs as pairs} from './preview-comparison-transform.mjs';
const check=(condition,message)=>{if(!condition)throw Error(message);};
const mean=rows=>rows.reduce((a,b)=>a+b,0)/rows.length;
const median=rows=>{const sorted=rows.slice().sort((a,b)=>a-b);return sorted.length%2?sorted[(sorted.length-1)/2]:mean(sorted.slice(sorted.length/2-1,sorted.length/2+1));};
export function summarizeShadowInputs(areas){
 check(areas?.length===modes.length,'Expected twelve shadow input comparison visits');
 const phases=areas.map((area,index)=>{
  const audit=area.shadowAudit,sample=area.samples.at(-1),view=sample?.frame?.viewport,metrics=frameMetrics(area.frames);
  check(area.pass===index&&area.shadowInputs===modes[index],'Shadow input mode/order mismatch');
  check(metrics.complete&&metrics.frames>=120,'Incomplete shadow input frame observation');
  check(view?.bufferWidth===3440&&view?.bufferHeight===1369&&view?.pixelRatio===1,'Shadow input render size mismatch');
  check(sample?.shadowBudget?.native?.maximum===1,'Shadow input shadow setting mismatch');
  check(sample?.scene?.controlled?.rendered&&sample.scene.objects>=100&&area.movingActors>=10,'Shadow input crowd fixture incomplete');
  check(audit?.telemetry?.shadowInputEarlyExit===modes[index]&&audit.flags.shadowInputs===modes[index],'Shadow input flag did not apply');
  check(Object.entries(audit.flags).every(([key,value])=>key==='shadowInputs'||value===false),'Another candidate is enabled');
  check((audit.telemetry.particles??[]).every(particle=>!particle.failed),'Particle failures in shadow input fixture');
  const stages=area.samples.map(row=>row.shadowProfile?.telemetry?.stages).filter(Boolean),averageStage=key=>mean(stages.map(row=>row[key]?.totalMs??0));
  return{pass:index,enabled:modes[index],resRef:area.resRef,loadMs:area.loadMs,...metrics,objects:sample.scene.objects,
   sampledShadowMs:averageStage('shadowTotal'),sampledSubmissionMs:averageStage('shadowSubmission'),sampledInputsMs:averageStage('shadowInputs'),sampledGroupingMs:averageStage('shadowGrouping'),
   volatileSamples:stages.filter(row=>row.shadowInputResults?.volatile).length,shortCircuitSamples:stages.filter(row=>row.shadowInputResults?.shortCircuited).length};
 });
 const comparisons=pairs.map(([before,candidate,after])=>{
  const a=phases[before],b=phases[candidate],c=phases[after];check(a.resRef===b.resRef&&b.resRef===c.resRef,'Shadow input compared different areas');
  const fps=mean([a.fps,c.fps]),p95=mean([a.p95Ms,c.p95Ms]),drift=(Math.max(a.fps,c.fps)/Math.min(a.fps,c.fps)-1)*100,warnings=[];
  if(drift>5)warnings.push('Neighbor baseline FPS differs by more than 5%');if(a.objects!==b.objects||b.objects!==c.objects)warnings.push('Object population differs');if(!b.shortCircuitSamples)warnings.push('No volatile map shortcut observed');
  return{before,candidate,after,resRef:b.resRef,baselineFps:fps,candidateFps:b.fps,fpsChangePercent:(b.fps/fps-1)*100,p95ChangePercent:(b.p95Ms/p95-1)*100,baselineSpreadPercent:drift,warnings};
 });
 return{scope:'Isolated shadow input scan candidate, other candidates disabled; four same-area neighbor pairs after four warmups. Sampled inclusive CPU/driver timing, not GPU time.',phases,comparisons,medianFpsChangePercent:median(comparisons.map(row=>row.fpsChangePercent)),enableByDefault:false,goalComplete:false};
}

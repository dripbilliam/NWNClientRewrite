const rows=[
 ['fps','FPS'],['frame','Frame avg / p95'],['peak','Worst / hitches >50ms'],
 ['work','Frame work'],['render','Render submission'],['network','Network visuals'],
 ['presentation','Other presentation'],['particles','Particles'],['camera','Camera / lights'],
 ['cameraAndAudio','Camera / audio'],['keyhole','Keyhole'],['overlay','Labels / picking'],
 ['matrices','World matrices'],['membership','Scene membership'],['selection','Light selection'],
 ['shadowBudget','Shadow budgeting'],['lightSlots','Light shader slots'],['metadata','Debug metadata'],
 ['draws','Main / shadow draws'],['triangles','Main / shadow triangles'],
 ['reuse','Shadow maps reused'],
 ['particleWorkers','Particle workers / pending frame'],
 ['resolution','Render resolution'],['display','Viewport / pixel ratio'],
 ['lights','Lights / shadows'],['slots','Point shader slots'],['programs','Cached shaders / new'],
 ['loading','Pending assets / shaders'],['models','Model preparations / failed'],
 ['memory','Geometries / textures'],['heap','Renderer JS heap']
];
const number=value=>Number(value||0).toLocaleString(undefined,{maximumFractionDigits:0});
const ms=value=>`${value.toFixed(1)} ms`;
export class RendererPerformanceView{
 constructor(root){
  this.root=root;this.samples=[];this.lastAt=null;this.lastPublish=-Infinity;this.lastPrograms=null;this.peak=0;this.hitches=0;
  const primary=new Set(['fps','frame','peak','render','loading','programs']),markup=list=>'<dl>'+list.map(([id,label])=>`<div><dt>${label}</dt><dd data-performance="${id}">—</dd></div>`).join('')+'</dl>';
  root.innerHTML='<div class="performance-heading"><span class="eyebrow">PERFORMANCE</span><button type="button" class="performance-reset">Reset peaks</button></div>'+markup(rows.filter(([id])=>primary.has(id)))+'<details><summary>More performance details</summary>'+markup(rows.filter(([id])=>!primary.has(id)))+'</details><p>FPS uses a 2-second window. Times measure CPU work and driver waits, not GPU time or server ping.</p>';
  this.fields=new Map([...root.querySelectorAll('[data-performance]')].map(n=>[n.dataset.performance,n]));
  root.querySelector('button').addEventListener('click',()=>{this.peak=0;this.hitches=0;});
 }
 record({at,timing,rendered,visible=true,details:readDetails}){
  if(!visible){this.samples=[];this.lastAt=null;return;}
  // Completion-to-completion gaps include the current long draw immediately;
  // callback deltas alone would report that stall one frame too late.
  const gap=this.lastAt===null?timing.totalMs:Math.max(0,at-this.lastAt);this.lastAt=at;
  const programs=timing.programsAfter,added=this.lastPrograms===null?0:Math.max(0,programs-this.lastPrograms);this.lastPrograms=programs;
  this.peak=Math.max(this.peak,gap);if(gap>50)this.hitches++;
  this.samples.push({at,gap,rendered,added,timing});while(this.samples.length>1&&this.samples[0].at<at-2000)this.samples.shift();
  if(at-this.lastPublish<500)return;this.lastPublish=at;
  const samples=this.samples,count=samples.length,elapsed=samples.reduce((n,s)=>n+s.gap,0),intervals=samples.map(s=>s.gap).sort((a,b)=>a-b);
  const avg=key=>samples.reduce((n,s)=>n+s.timing[key],0)/count;
  const stage=key=>samples.reduce((n,s)=>n+(s.timing.cameraStages?.[key+'Ms']??0),0)/count;
  const fps=elapsed>0?samples.filter(s=>s.rendered).length*1000/elapsed:0;
  const details=readDetails(),{draw={},shadow={},viewport={},lighting={},models={},memory={}}=details,point=lighting.slots?.point,selection=lighting.selection,budget=lighting.shadows;
  const values={fps:`${fps.toFixed(1)}${rendered?'':' · preparing'}`,frame:`${ms(elapsed/count)} / ${ms(intervals[Math.ceil(count*.95)-1])}`,peak:`${ms(this.peak)} / ${number(this.hitches)}`,work:ms(avg('totalMs')),render:ms(avg('renderMs')),network:ms(avg('networkMs')),presentation:ms(avg('presentationMs')),particles:ms(avg('particlesMs')),camera:ms(avg('cameraAndShadowsMs')),
   ...Object.fromEntries(['cameraAndAudio','keyhole','overlay','matrices','membership','selection','shadowBudget','lightSlots','metadata'].map(key=>[key,ms(stage(key))])),
   draws:`${rendered?number(draw.calls):'—'} / ${rendered?number(shadow.drawCalls):'—'}`,triangles:`${rendered?number(draw.triangles):'—'} / ${rendered?number(shadow.triangles):'—'}`,
   reuse:`${number(shadow.reusedLights)} reused · ${number(shadow.renderedLights)} drawn`,particleWorkers:`${details.particleWorkers?.workers??0} / ${Number(Boolean(details.particleWorkers?.pending))}`,resolution:`${viewport.bufferWidth} × ${viewport.bufferHeight}`,display:`${viewport.width} × ${viewport.height} · ${viewport.pixelRatio}×`,
   lights:`${selection?.admitted??0} active · ${budget?.admitted??0}/${budget?.requested??0} shadows`,slots:`${point?.actual??0}/${point?.capacity??0} lights · ${point?.shadowActual??0}/${point?.shadowCapacity??0} shadows`,
   programs:`${number(programs)} / +${number(samples.reduce((n,s)=>n+s.added,0))}`,loading:`${number(details.pendingAssets)} / ${number(models.pending)}`,models:`${number(models.compilations)} / ${number(models.failed)}`,memory:`${number(memory.geometries)} / ${number(memory.textures)}`,heap:details.heapBytes===undefined?'Unavailable':`${(details.heapBytes/1048576).toFixed(1)} MiB`};
  for(const [id,value]of Object.entries(values))if(this.fields.get(id).textContent!==value)this.fields.get(id).textContent=value;
  this.root.dataset.state=JSON.stringify({fps,averageFrameMs:elapsed/count,p95FrameMs:intervals[Math.ceil(count*.95)-1],worstFrameMs:this.peak,hitches:this.hitches,preparing:!rendered,programs,pendingAssets:details.pendingAssets,pendingShaders:models.pending});
 }
}

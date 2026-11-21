const test=require('node:test'),assert=require('node:assert/strict'),{weatherIntegrationComplete,weatherRenderIntegrationComplete}=require('./weather-evidence.cjs');
// Authored positive/negative gate fixtures, independent of ignored run reports.
// Actual localhost evidence is validated separately by the milestone script.
function report(){
 const scope={connection:1,areaId:7,generation:1,transferId:1},checks=()=>Array.from({length:22},()=>({passed:true}));
 const r={nativeLoaded:[scope],presentations:[{...scope,screenshot:'authored.png',distance:1,cameraFollow:true,animation:{changed_local_parts:1,maximum_local_skin_vertex_delta:.1}}],gameplayTest:{completed:true,checks:checks()},gameplayText:{examine:1,'dialog-entry':3,'dialog-close':2,floating:1},commands:[{kind:'examine'},...Array.from({length:3},()=>({kind:'reply'}))],weatherWire:[],weatherDelivered:[],weatherObserved:[],weatherTest:{completed:true,presentationPending:true,checks:checks(),phases:[]}};
 const sequence=[0,1,2,0,1,0];for(const [index,type]of sequence.entries()){
  const revision=index+1,enabled=index!==0;
  r.weatherDelivered.push({...scope,revision,weather:{type,enabled}});r.weatherObserved.push({...scope,revision,applied:true});
  if(index){r.weatherWire.push({connection:1,weather:{type,enabled:1}});r.weatherTest.phases.push({type,enabled,revision,acknowledged:true,state:{current:type,target:type,intensity:type?100:0,plannedInstances:type?6:0,remainingMs:0,presentationPending:true}});}
 }
 return r;
}
test('complete scoped packet/delivery/observation/endpoints qualify state-only weather evidence',()=>assert.equal(weatherIntegrationComplete(report()),true));
test('normal gameplay, duplicate revisions or missing wire/observation cannot qualify as weather evidence',()=>{
 for(const alter of [r=>delete r.weatherTest,r=>delete r.weatherWire,r=>r.weatherWire.reverse(),r=>r.weatherTest.phases[1].revision=r.weatherTest.phases[0].revision,r=>r.weatherObserved.pop(),r=>r.weatherDelivered.pop()]){const r=report();alter(r);assert.equal(weatherIntegrationComplete(r),false);}
});
test('stale ownership, fabricated visual-completion and incorrect model retirement are rejected',()=>{
 for(const alter of [r=>r.weatherObserved.at(-1).connection++,r=>r.weatherObserved.at(-1).transferId++,r=>r.weatherTest.presentationPending=false,r=>r.weatherTest.phases.at(-1).state.plannedInstances=6,r=>r.weatherTest.phases.at(-1).state.remainingMs=1,r=>r.weatherTest.phases.at(-1).state.current=1,r=>r.weatherTest.checks[0].passed=false]){const r=report();alter(r);assert.equal(weatherIntegrationComplete(r),false);}
});
function rendered(){
 const r=report(),t=r.weatherTest;t.renderingRequired=true;
 for(let i=1;i<3;i++){r.nativeLoaded.push({...r.nativeLoaded[0],areaId:i===1?8:7,generation:i+1,transferId:i+1});r.presentations.push({...r.presentations[0],...r.nativeLoaded[i]});}
 t.renderSamples=Array.from({length:3},()=>({changedPixels:24,vertices:120,emitters:24,saved:true,models:{models:6,particleReady:true,stats:{failures:0}}}));
 t.firstRenderer={models:0,stats:{created:18,removed:18,failures:0}};
 t.transitions=r.nativeLoaded.slice(1).map((scope,i)=>({...scope,ready:true,oldWeatherAlive:false,oldModelsAlive:0,renderer:{models:6,current:i===0?2:1,stats:{failures:0}}}));t.renderer=t.transitions[1].renderer;
 return r;
}
test('state-only completion cannot qualify as actual weather rendering or world retirement',()=>{assert.equal(weatherRenderIntegrationComplete(report()),false);assert.equal(weatherRenderIntegrationComplete(rendered()),true);});
test('weather-only pixels, all emitters, both area replacements and old-owner destruction are mandatory',()=>{
 for(const change of [r=>r.weatherTest.renderSamples[0].changedPixels=0,r=>r.weatherTest.renderSamples[0].emitters=23,r=>r.weatherTest.firstRenderer.stats.removed=12,r=>r.weatherTest.transitions[0].oldModelsAlive=1,r=>r.weatherTest.transitions[1].oldWeatherAlive=true,r=>r.weatherTest.transitions[1].renderer.models=0,r=>r.nativeLoaded.pop()]){const r=rendered();change(r);assert.equal(weatherRenderIntegrationComplete(r),false);}
});

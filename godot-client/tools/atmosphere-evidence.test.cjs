const test=require('node:test'),assert=require('node:assert/strict');
const {atmosphereIntegrationComplete:complete}=require('./atmosphere-evidence.cjs');
function report(){
 const nativeLoaded=[1,2,1].map((areaId,i)=>({connection:1,areaId,generation:i+1,transferId:i+1}));
 const rgb=n=>[n&255,n>>>8&255,n>>>16&255].map(v=>v/255);
 return{success:true,disconnected:true,nativeExit:0,nativeLoaded,rendererErrors:[],nativeErrors:'',commands:nativeLoaded.slice(0,2).map(v=>({...v,kind:'interact'})),presentations:nativeLoaded.map(v=>({...v,screenshot:'authored.png',distance:1,cameraFollow:true,animation:{changed_local_parts:1,maximum_local_skin_vertex_delta:.1},cleanup:{alive:0}})),portalRegionPhases:nativeLoaded.map((v,i)=>({...v,area:i===1?'dense_b':'dense_a',portalId:10+i,final:i===2,completed:true,checks:Array.from({length:i===2?4:5},()=>({passed:true}))})),environments:nativeLoaded.map((v,i)=>({...v,applied:true,state:{revision:i+1,fog:true,phaseUpdates:1,updates:1,elapsed:1,range:{end:45,far:45},background:rgb(i===1?0x443322:0x668899),sample:{complete:true,isNight:i===1,amount:i===1?15:5,fog:rgb(i===1?0x443322:0x668899),ambient:rgb(i===1?0x665544:0x99aabb),diffuse:rgb(i===1?0x887766:0xddeeff)}}}))};
}
test('complete native day/night/day admission evidence passes the gate',()=>assert.equal(complete(report()),true));
test('missing, stale or incorrect atmosphere and portal evidence cannot be promoted',()=>{
 for(const mutate of [r=>r.environments.pop(),r=>r.environments[1].generation=1,r=>r.environments[1].connection=2,r=>r.environments[2].transferId=1,r=>r.environments[1].applied=false,r=>r.environments[1].state.sample.isNight=false,r=>r.environments[1].state.sample.amount=5,r=>r.environments[1].state.background=[0,0,0],r=>r.environments[1].state.sample.diffuse=[1,1,1],r=>r.environments[1].state.range.end=120,r=>r.environments[2].state.fog=false,r=>r.nativeExit=1,r=>r.disconnected=false,r=>r.presentations[1].cleanup.alive=1,r=>r.success=false]){const r=report();mutate(r);assert.equal(complete(r),false,mutate.toString());}
});

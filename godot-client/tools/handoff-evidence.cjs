const {integrationComplete}=require('./integration-evidence.cjs');
function handoffIntegrationComplete(r,{beforeShutdown=false,characterMode='bic'}={}){
 if(!['bic','reference'].includes(characterMode))return false;
 if(!integrationComplete('text',r)||r.failure||r.rejectedCommands?.length||r.nativeLoaded?.length!==3||r.handoffGameplay?.length!==3||r.handoffArrivals?.length!==3||r.portalCharacters?.length!==2||r.portalAdoptions?.length!==6||r.portalCleanup?.length!==2)return false;
 if(beforeShutdown?(r.nativeExit!==undefined&&r.nativeExit!==0):(r.nativeExit!==0||r.disconnected!==true))return false;
 if(r.diagnostics?.some(d=>['network.portal-failed','network.portal-connect-failed','godot.particle-frame-failed'].includes(d.code)))return false;
 if(r.areas?.map(v=>v.area).join(',')!=='dense_a,dense_b,dense_a'||r.characterSaves?.map(v=>v.connection).join(',')!=='1,2,3'||r.characterReads?.some(v=>v.connection!==1))return false;
 if(!r.characterSaves.every(v=>v.bytes>1000&&/^[a-f0-9]{64}$/.test(v.sha256)))return false;
 for(let i=0;i<3;i++){
  const c=i+1,l=r.nativeLoaded[i],a=r.handoffArrivals[i],p=r.presentations.find(v=>v.connection===c),g=r.handoffGameplay[i];
  if(l.connection!==c||l.generation!==1||g.connection!==c||g.areaId!==l.areaId||g.generation!==l.generation||!g.result?.completed||g.result.checks?.length!==16||g.result.checks.some(v=>!v.passed)||p?.cleanup?.alive!==0)return false;
  if(a.connection!==c||a.area!==r.areas[i].area||a.endpoint!==`127.0.0.1:${i===1?5122:5121}`||a.phase!=='playing'||a.confirmed!==true||a.waypointRequests<1||a.waypointRemaining!==''||!Array.isArray(a.position))return false;
  // The native server can adjust an occupied waypoint to a nearby safe spot.
  if(i>0&&Math.hypot(a.position[0]-52,a.position[1]-40)>1)return false;
 }
 for(let i=0;i<2;i++){
  const v=r.portalCharacters[i],events=r.portalAdoptions.slice(i*3,i*3+3),cleanup=r.portalCleanup[i];
  const characterValid=characterMode==='bic'?v.kind==='bic'&&v.bytes>=1000:v.kind==='reference'&&v.bytes===0&&[2,17].includes(v.source)&&typeof v.resref==='string'&&v.resref.length>0&&v.resref.length<=16;
  if(v.originConnection!==i+1||v.originReleased!==true||!characterValid||events.map(v=>v.stage).join(',')!=='prepared,adopting,installed'||events.some(v=>v.from!==i+1||v.to!==i+2||v.endpoint?.host!=='127.0.0.1'||v.endpoint.port!==(i===0?5122:5121))||cleanup.connection!==i+2||cleanup.remainingThreads!==0)return false;
 }
 return r.particles?.epochs?.length===3&&r.particles.epochs.every((v,i)=>beforeShutdown&&i===2||v.closed&&v.pendingJobs===0&&v.remainingThreads===0);
}
module.exports={handoffIntegrationComplete};

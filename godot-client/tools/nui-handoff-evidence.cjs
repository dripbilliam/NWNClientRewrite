const {handoffIntegrationComplete}=require('./handoff-evidence.cjs');
function nuiHandoffIntegrationComplete(r,options={}){
 const p=r.nuiHandoffPhases,stale=r.nuiStaleInputs,rejected=r.rejectedCommands;
 if(p?.length!==3||stale?.length!==2||rejected?.length!==2)return false;
 for(let i=0;i<2;i++)if(stale[i].connection!==i+1||stale[i].current!==i+2||stale[i].operation!=='close'||stale[i].windowId!==p[i].result?.rootWindowId||rejected[i].kind!=='nui-input'||rejected[i].connection!==i+1||rejected[i].reason!=='Native input belongs to an old connection')return false;
 if(!handoffIntegrationComplete({...r,rejectedCommands:[]},options)||r.diagnostics?.some(v=>String(v.code).startsWith('godot.nui-')||v.code==='network.nui-resource-unavailable'))return false;
 if(!r.portalCleanup.every(v=>v.nui?.closed&&v.nui.pendingResources===0)||!options.beforeShutdown&&(!r.nuiCleanup?.closed||r.nuiCleanup.pendingResources!==0))return false;
 return p.every((v,i)=>{
  const t=v.result,label=i===1?'B':'A',checks=i?17:14;
  return v.connection===i+1&&v.canonical===true&&t?.completed&&t.label===label&&t.checks?.length===checks&&t.checks.every(c=>c.passed)&&t.statistics?.failed===0&&t.windows===2&&t.retired?.windows===0&&t.retired.resources===0&&t.screenshot?.endsWith('-c'+(i+1)+'-nui.png')&&t.rootWindowId===p[0].result.rootWindowId&&Number.isInteger(v.rootToken)&&v.rootToken===p[0].rootToken&&Number.isInteger(v.childToken)&&v.childToken===p[0].childToken&&r.nuiRequests?.some(q=>q.connection===i+1&&q.element==='child'&&q.type==='click')&&r.nuiRequests.some(q=>q.connection===i+1&&q.element==='ack'&&q.type==='click')&&r.nuiRequests.some(q=>q.connection===i+1&&q.bind==='name');
 });
}
module.exports={nuiHandoffIntegrationComplete};

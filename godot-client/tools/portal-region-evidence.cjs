const {integrationComplete}=require('./integration-evidence.cjs');
function portalRegionIntegrationComplete(report){
 const phases=report.portalRegionPhases,loads=report.nativeLoaded;
 if(!integrationComplete('smoke',report)||report.rejectedCommands?.length||phases?.length!==3||loads?.length!==3||phases.map(v=>v.area).join(',')!=='dense_a,dense_b,dense_a'||new Set(phases.map(v=>v.generation)).size!==3)return false;
 if(!phases.every((p,i)=>p.completed&&p.final===(i===2)&&p.checks?.length===(i===2?4:5)&&p.checks.every(c=>c.passed)&&Number.isInteger(p.portalId)&&loads[i].areaId===p.areaId&&loads[i].generation===p.generation))return false;
 return report.commands.filter(v=>v.kind==='interact').length===2&&phases.slice(0,2).every(p=>report.commands.some(v=>v.kind==='interact'&&v.areaId===p.areaId&&v.generation===p.generation))&&report.presentations.every(p=>p.cleanup?.alive===0)&&loads[0].areaId===loads[2].areaId&&loads[0].areaId!==loads[1].areaId;
}
module.exports={portalRegionIntegrationComplete};

const {portalRegionIntegrationComplete}=require('./portal-region-evidence.cjs');
const rgb=n=>[n&255,n>>>8&255,n>>>16&255].map(v=>Math.fround(v/255));
const near=(a,b)=>Array.isArray(a)&&a.length===3&&a.every((v,i)=>Number.isFinite(v)&&Math.abs(v-b[i])<.000001);
function atmosphereIntegrationComplete(report){
 if(!portalRegionIntegrationComplete(report)||report.success!==true||report.disconnected!==true||report.nativeExit!==0||report.environments?.length!==3)return false;
 return report.environments.every((e,i)=>{
  const load=report.nativeLoaded[i],s=e.state,night=i===1;
  return e.applied===true&&['connection','areaId','generation','transferId'].every(k=>e[k]===load[k])&&s?.revision>=1&&s.fog===true&&s.phaseUpdates===1&&s.updates>=1&&s.elapsed>=0&&s.range?.end===45&&s.range.far===45&&s.sample?.complete===true&&s.sample.isNight===night&&s.sample.amount===(night?15:5)&&near(s.background,rgb(night?0x443322:0x668899))&&near(s.sample.fog,s.background)&&near(s.sample.ambient,rgb(night?0x665544:0x99aabb))&&near(s.sample.diffuse,rgb(night?0x887766:0xddeeff));
 });
}
module.exports={atmosphereIntegrationComplete};

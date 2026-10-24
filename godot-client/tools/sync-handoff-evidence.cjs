const {nuiHandoffIntegrationComplete}=require('./nui-handoff-evidence.cjs');
function syncHandoffIntegrationComplete(r,options={}){
 const f=r.syncHandoffFixture,p=r.syncHandoffPhases,a=r.syncHandoffAdvertisements;
 if(!nuiHandoffIntegrationComplete(r,options)||f?.reuseInstalledNWSync!==false||f.resources!==15||f.manifests?.length!==2||f.manifests[0]===f.manifests[1]||!f.manifests.every(v=>/^[a-f0-9]{40}$/.test(v))||p?.length!==3||a?.length!==3)return false;
 if(JSON.stringify(f.pixels)!==JSON.stringify([[240,170,20,255],[40,100,220,255]]))return false;
 return p.every((v,i)=>{
  const c=i+1,label=i===1?'B':'A',n=r.nuiHandoffPhases[i].result,progress=n.download?.progress,expected=f.manifests[i===1?1:0],capture=n.download?.capture;
  if(v.connection!==c||v.label!==label||v.expectedHash!==expected||a[i].connection!==c||a[i].hash!==expected||v.resources?.length!==15||new Set(v.resources.map(e=>e.name+':'+e.type)).size!==15||v.resources.some(e=>!e.match||e.hash!==e.expected||!/^[a-f0-9]{40}$/.test(e.hash)||e.size<=0)||v.unmounted!==true||v.absent!=='gd_only_'+(label==='A'?'b':'a')||!Number.isSafeInteger(v.readyAt)||v.readyAt<=0||i>0&&v.readyAt<=p[i-1].readyAt)return false;
  if(JSON.stringify(n.iconPixel)!==JSON.stringify(f.pixels[i===1?1:0])||!progress?.length||!progress.every(q=>q.connection===c&&!q.canPlay&&q.canCancel)||!progress.some(q=>q.phase==='server-content'&&q.completed===15&&q.total===15))return false;
  return i===2?progress.every(q=>q.downloadedBytes===0):progress.some(q=>q.downloadedBytes>0)&&capture?.canCancel===true&&capture.playDisabled===true&&Boolean(capture.screenshot);
 });
}
module.exports={syncHandoffIntegrationComplete};

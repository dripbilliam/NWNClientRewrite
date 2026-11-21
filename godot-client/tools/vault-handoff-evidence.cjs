const {handoffIntegrationComplete}=require('./handoff-evidence.cjs');
function vaultHandoffIntegrationComplete(r,options={}){
 if(!handoffIntegrationComplete(r,{...options,characterMode:'reference'})||r.characterReads?.length!==0||r.vaultAdmissions?.length!==3||r.vaultExports?.length!==3||!r.vaultSeed?.generatedByReplacement||!r.vaultSeed.sharedVault||r.vaultSeed.reference!=='native_hand'||![2,17].includes(r.vaultSeed.source)||r.vaultSeed.bytes<1000||!/^[a-f0-9]{64}$/.test(r.vaultSeed.sha256))return false;
 if(r.portalCharacters.some(v=>v.source!==r.vaultSeed.source||v.resref!==r.vaultSeed.reference))return false;
 if(!['lobby-choose','lobby-play'].every(kind=>r.commands.filter(v=>v.kind===kind).length===1&&r.commands.some(v=>v.kind===kind&&v.connection===1&&v.key==='server:'+r.vaultSeed.source+':native_hand')))return false;
 const wire=r.vaultWire;if(!Array.isArray(wire)||wire.some(v=>v.major===2&&[1,4,19].includes(v.minor)))return false;
 for(let i=0;i<3;i++){
  const c=i+1,a=r.vaultAdmissions[i],e=r.vaultExports[i],plays=wire.filter(v=>v.connection===c&&v.major===2&&v.minor===r.vaultSeed.source);
  if(a.connection!==c||a.localAllowed!==false||a.uploaded!==false||a.submitted!==true||a.confirmed!==true||a.source!==r.vaultSeed.source||a.resref!=='native_hand'||plays.length!==1||plays[0].correctReference!==true||e.connection!==c||e.firstName!=='Native'||e.lastName!=='Vault Handoff'||e.classId!==10||e.level!==1||!e.bytes||!/^[a-f0-9]{64}$/.test(e.sha256))return false;
 }
 return wire.filter(v=>v.major===43&&v.minor===1).map(v=>v.connection).join(',')==='1,2';
}
module.exports={vaultHandoffIntegrationComplete};

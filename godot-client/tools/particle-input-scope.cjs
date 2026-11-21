// Only renderer work belonging to an actually allocated particle epoch may be
// drained after retirement. Gameplay commands and unknown scopes still reject.
function particleInputScope(message,current,epoch,known){
 if(!['particles-start','particle-frame'].includes(message?.kind)||!['connection','areaId','generation','epoch'].every(k=>Number.isSafeInteger(message[k])&&message[k]>=0))return'unknown';
 const same=(a,b)=>b&&['connection','areaId','generation'].every(k=>a[k]===b[k])&&(a.transferId===undefined||a.transferId===b.transferId);
 const owner=known.find(v=>v.epoch===message.epoch&&same(message,v.scope));
 if(!owner)return'unknown';
 return message.epoch===epoch&&same(message,current)?'current':'retired';
}
module.exports={particleInputScope};

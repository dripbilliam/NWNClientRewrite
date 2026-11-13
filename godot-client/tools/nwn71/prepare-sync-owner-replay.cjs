'use strict';
// Preserve the existing offline replay; bind a diagnostic-only private engine.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),stage=path.join(root,'.cache/nwn71/sync-owner-clock-a');
const source=path.join(root,'tools/nwn74/replay-inner-phase-clock.mjs'),dest=path.join(__dirname,'replay-sync-owner-clock.mjs');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
assert(!fs.existsSync(dest),'Preserve previous private replay');
const before=fs.readFileSync(source,'utf8');assert.equal(sha(Buffer.from(before)),'fcdf059f9bccca7569d9facf88750f36fcc9e134c52b912d34058bb9f1f2752e');
let after=before;
function one(a,b){assert.equal(after.split(a).length,2,'Replay anchor differs: '+a.slice(0,75));after=after.replace(a,b);}
one('.cache/nwn74/inner-phase-clock-a/build-receipt.json','.cache/nwn71/sync-owner-clock-a/build-receipt.json');
after=after.replaceAll('28e5d6e4c22ecbddab2a50dfe9e074041c7e6c524813d34cd42dfb7752738c17','32cea75ad505e774df16ae25c971f849515396f68c145ab83ec5ee62525744e5');
one('nwn74Receipt.acceptedSourceUnchanged!==true','nwn74Receipt.acceptedSourcesUnchanged!==true');
one('issue:"NWN-74",accepted:false','issue:"NWN-71",accepted:false');
fs.writeFileSync(dest,after,{flag:'wx'});
const receipt={issue:'NWN-71',private:true,source,sourceSha256:sha(Buffer.from(before)),driver:dest,driverSha256:sha(Buffer.from(after)),engineSha256:'32cea75ad505e774df16ae25c971f849515396f68c145ab83ec5ee62525744e5',fpsOutputDisabled:true,gate:'NWN71_SYNC_OWNER_CLOCK=1',selection:'Pinned original-scene offline generation-2 replay; diagnostic only'};
fs.writeFileSync(path.join(stage,'driver-receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(receipt));

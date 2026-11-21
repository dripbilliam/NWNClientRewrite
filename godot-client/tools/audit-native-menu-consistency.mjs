// Scoped current menu acceptance; the entire UI goal remains unfinished.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const home=fileURLToPath(new URL('../',import.meta.url)),evidence=[];
const hash=b=>createHash('sha256').update(b).digest('hex');
async function read(file){const b=await fs.readFile(path.join(home,file));evidence.push({file,sha256:hash(b)});return JSON.parse(b);}
let currentMenuInputChecks=0,unchangedDependencySupportChecks=0;
async function pinned(name,count,support=false){
 const stem='reports/native-menu-consistency-'+name,r=await read(stem+'.json'),d=await read(stem+'.debugger.json');
 assert.equal(r.success,true);assert.deepEqual(r.failures,[]);assert.equal(r.checks,count);assert.equal(r.publicConnections??r.public_connections,0);
 for(const k of ['success','sourceUnchanged','armed'])assert.equal(d[k],true,k);
 for(const k of ['exception','engineOrLifetimeError'])assert.equal(d[k],false,k);
 assert.equal(d.debuggerExit,0);const changed=[];
 for(const[file,digest]of Object.entries(d.sourceSha256)){if(hash(await fs.readFile(path.join(home,file)))!==digest)changed.push(file);}
 assert.deepEqual(changed,support?['systems/server_browser.gd']:[],name+' unexpected source changes');
 if(support)unchangedDependencySupportChecks+=count;else currentMenuInputChecks+=count;
 return r;
}
for(const[name,count]of [['pregame-current-v1',27],['ingame-current-v1',36],['multiplayer-final-v1',35]])await pinned(name,count);
for(const[name,count]of [['style-final-v1',15],['settings-final-v1',38],['disconnect-final-v1',14],['prework-final-v1',38],['sampler-final-v1',126],['actors-final-v1',23]])await pinned(name,count,true);
for(const[name,suffix,visualReview]of [
 ['pregame-current-v1','-main','Original main-menu artwork and literal News caption reviewed.'],
 ['pregame-current-v1','-options','Original Options source controls reviewed.'],
 ['ingame-current-v1','-normal','Original in-game menu source layout reviewed.'],
 ['ingame-current-v1','-scaled','Original menu at125% scale reviewed.'],
 ['style-final-v1','.graphics','Client Options matches the original font/art family; unchecked/checked controls visually distinct.'],
 ['style-final-v1','.interface','Themed Interface page and actual persisted checkbox state reviewed.']
]){
 const file='reports/native-menu-consistency-'+name+suffix+'.png',b=await fs.readFile(path.join(home,file));assert.equal(b.subarray(1,4).toString(),'PNG');evidence.push({file,sha256:hash(b),visualReview});
}
const original=await read('../backups/animations/rea-native-menu-consistency-v1.json');assert.equal(original.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.ok(original.rows.client_style_checkbox.normalized_result.pseudocode.includes('Gui_Anim_UnChecked_Up'));
const inspection=await read('reports/native-menu-consistency-art-inspect-v2.json');assert.equal(inspection.success,true);assert.equal(inspection.captions.RepoNewsButton.AurString_Text,'News');assert.ok(inspection.models.ctl_chk_pre.clips.some(v=>v.name==='uncheckedup'));
const info=await fs.readFile(path.join(home,'systems/native_data/gui_texture_info.gd'),'utf8');assert.ok(info.includes('original-gui-sampler-v3-source-culling'));
const archive='backups/native-menu-consistency-v1.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(hash(await fs.readFile(path.join(home,archive))),checkpoint.sha256);
for(const entry of checkpoint.manifest){const file=entry.sourceScope==='workspace'?path.join(home,'..',entry.source):path.join(home,entry.file);assert.equal(hash(await fs.readFile(file)),entry.sha256,entry.file+' changed since checkpoint');}
const result={success:true,goalComplete:false,fullUiParity:false,currentMenuInputChecks,unchangedDependencySupportChecks,supportingReceiptExcludedDifference:'systems/server_browser.gd; current entry/menu receipts cover its final artwork gating',publicGameplayConnections:0,checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},evidence,limits:'Original menu input/art and consistent replacement client-settings style only. Full ConfigWindow, remaining campaign/movie/news/storage actions, all other UI/role/resource/scale acceptance and complete parity remain open.'};
await fs.writeFile(path.join(home,'reports/native-menu-consistency-audit-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({...result,evidence:undefined}));

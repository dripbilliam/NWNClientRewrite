'use strict';
const fs=require('node:fs'),path=require('node:path'),{spawnSync}=require('node:child_process'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),directory=path.join(root,'.cache/nwn64/clock-review-pair-a'),proposal=JSON.parse(fs.readFileSync(path.join(directory,'proposal.json'))),parts=[];
for(const view of proposal.views)for(const row of view.overlays){
 const child=spawnSync('git',['-c','core.safecrlf=false','diff','--no-index','--',path.join(proposal.parent.source,row.relative),path.join(view.project,row.relative)],{encoding:'utf8',windowsHide:true,maxBuffer:1024*1024});assert(child.status===1);parts.push('PRIVATE '+view.mode+' / '+row.relative+'\n'+child.stdout);
}
for(const view of proposal.views)parts.push('PRIVATE DESCRIPTOR '+view.mode+'\n'+fs.readFileSync(path.join(view.project,view.descriptor.relative),'utf8'));
const file=path.join(directory,'private-overlays.diff.txt');assert(!fs.existsSync(file));fs.writeFileSync(file,parts.join('\n'),{flag:'wx'});console.log(JSON.stringify({file,sha256:crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'),bytes:fs.statSync(file).size}));

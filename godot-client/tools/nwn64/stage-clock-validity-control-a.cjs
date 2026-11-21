'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),input=path.join(root,'.cache/native-render-gap/particles/nwn64-clock-validity-a'),output=path.join(root,'.cache/native-render-gap/particles/nwn64-clock-validity-control-a');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
assert(!fs.existsSync(output));
const previous=JSON.parse(fs.readFileSync(path.join(input,'kernel-source-pins.json'),'utf8'));
const relative='native/particle_presentation.hpp',pins=[];
for(const row of previous.pins){
 const bytes=row.relative===relative?fs.readFileSync(path.join(root,relative)):fs.readFileSync(path.join(previous.project,row.relative));
 if(row.relative===relative)assert.equal(sha(bytes),'643dc50015c8f406aad9a9da3fe150a73dbd0b7853508799cdb1c70c319ac97f');
 else assert.equal(sha(bytes),row.sha256);
 const target=path.join(output,'kernel-project',row.relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes,{flag:'wx'});
 pins.push({relative:row.relative,bytes:bytes.length,sha256:sha(bytes)});
}
const manifest={version:1,issue:'NWN-64',project:path.join(output,'kernel-project'),pins,scope:'Current-source private control for canonical clock validity bypass; exact same closure and compiler as candidate.'};
fs.writeFileSync(path.join(output,'kernel-source-pins.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});
const changed=pins.filter(row=>row.sha256!==previous.pins.find(prior=>prior.relative===row.relative).sha256);
assert.deepEqual(changed.map(row=>row.relative),[relative]);
console.log(JSON.stringify({output,changed,files:pins.length}));

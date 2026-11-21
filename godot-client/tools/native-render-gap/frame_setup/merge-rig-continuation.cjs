const fs=require('fs'),path=require('path'),crypto=require('crypto');
const project=path.resolve(__dirname,'../../..'),stage=path.join(project,'.cache/native-render-gap/engine'),file=path.join(stage,'manifest.json'),m=JSON.parse(fs.readFileSync(file));
const proposal=path.join(project,'.cache/native-render-gap/particles/boundary-skin-v2-b'),proof=path.join(proposal,'overlay-receipt.json'),r=JSON.parse(fs.readFileSync(proof));
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const changes=[];
for(const name of ['rig_skin_publisher.h','rig_skin_publisher.cpp']){
 const relative='modules/nwn_particle_snapshot/'+name,original=path.join(m.source,relative),input=path.join(proposal,'engine-module',name),pin=r.outputs.find(p=>p.relative==='engine-module/'+name);
 if(!pin||sha(fs.readFileSync(input))!==pin.sha256)throw Error('Proposal pin differs');
 const old=m.modules.find(p=>p.relative.replaceAll('\\','/')===relative);
 if(!old||sha(fs.readFileSync(original))!==old.sha256)throw Error('Engine module drift');
 changes.push({relative,original,input,before:old.sha256,after:pin.sha256});
}
const receipt=path.join(stage,'upgrade-v2','rig-continuation-merge.json');if(fs.existsSync(receipt))throw Error('Already merged');
for(const c of changes){fs.copyFileSync(c.input,c.original);m.modules.find(p=>p.relative.replaceAll('\\','/')===c.relative).sha256=c.after;}
m.rigContinuation={file:proof,sha256:sha(fs.readFileSync(proof)),abi:2};
fs.writeFileSync(file,JSON.stringify(m,null,2)+'\n');fs.writeFileSync(receipt,JSON.stringify({success:true,changes,manifestSha256:sha(fs.readFileSync(file))},null,2)+'\n');console.log(JSON.stringify({success:true,changes:changes.length}));

'use strict';
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const pr=path.resolve(__dirname,'../../..'),stage=path.join(pr,'.cache/native-render-gap/engine'),mf=path.join(stage,'manifest.json'),m=JSON.parse(fs.readFileSync(mf)),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
if(m.revision!==6)throw Error('Expected retained failed V6 source');
const relative='modules/nwn_particle_snapshot/scene_boundary.cpp',file=path.join(m.source,relative),before=fs.readFileSync(file,'utf8');
const pin=m.modules.find(x=>x.relative.replaceAll('\\','/')===relative);if(sha(before)!==pin.sha256||before.split('\n return OK;\n').length!==2)throw Error('Status source drift');
const after=before.replace('\n return OK;\n','\n return nwn_particle_scene_direct_v1::OK;\n'),saved=path.join(stage,'fix-v6-direct-status');if(fs.existsSync(saved))throw Error('Evidence preserved');fs.mkdirSync(saved);fs.copyFileSync(mf,path.join(saved,'previous-manifest.json'));fs.writeFileSync(path.join(saved,'scene_boundary.cpp'),before);fs.writeFileSync(file,after);pin.sha256=sha(after);m.revision='6.1';m.upgradeV6.compileCorrection='Qualify direct status OK to distinguish Godot Error::OK. Failed V6 receipt preserved.';fs.writeFileSync(mf,JSON.stringify(m,null,2)+'\n');console.log(JSON.stringify({success:true,relative,before:sha(before),after:sha(after)}));

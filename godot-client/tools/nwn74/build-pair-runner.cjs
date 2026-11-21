'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const base=__dirname,source=path.join(base,'run-render-probe.cjs'),target=path.join(base,'run-pair-probe.cjs');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const original=fs.readFileSync(source);assert.equal(sha(original),'c3cbde2caad7ed1cb55fb464fbbda7367352b43d7505d54aa304e0556edab673');
assert(!fs.existsSync(target));let code=original.toString();
function rep(a,b){assert.equal(code.split(a).length,2,'Runner seam changed: '+a);code=code.replace(a,b);}
rep("const label=process.argv[2],verifyOnly=process.argv.includes('--verify-only');\nassert.equal(label,'render-probe-a');", "const mode=process.argv[2],verifyOnly=process.argv.includes('--verify-only');\nassert(['off','consumer'].includes(mode));const label='render-probe-a';");
rep("const driver=path.join(__dirname,'replay-render-probe.mjs'),driverSha='cafcf235c0e4fc9ba72a2d842d85c15b24ce1a9344c0336a3a2362873b13d15b';", "const driver=path.join(__dirname,'replay-pair-probe.mjs'),driverSha='f710b36bd126488f42729aaf3879d4cb1624db3c834b908719683c992676bb17';");
rep("const run='nwn74-render-probe-c',reportFile=path.join(root,'reports',run+'.json');", "const run='nwn74-pair-entry-a-'+mode,reportFile=path.join(root,'reports',run+'.json');");
rep("'--preview','--run='+run]", "'--preview','--nwn74-pair-index='+mode,'--run='+run]");
rep(" assert.equal(sha(driver),driverSha);", " assert.equal(sha(driver),driverSha);\n const c=JSON.parse(fs.readFileSync(path.join(root,'.cache/nwn74/engine-build-c/receipt.json')));\n assert.equal(c.success,true);assert.equal(c.originalUntouched,true);assert.equal(c.priorCandidateUntouched,true);\n assert.equal(c.binary.sha256,'07d0989649b6b4722921cca2d0ce2960cfe8b732e012a9a8dfda134a8f96afe5');\n assert.equal(sha(c.binary.file),c.binary.sha256);\n assert.equal(sha(path.join(root,'.cache/nwn74/engine-source-a/servers/rendering/renderer_scene_cull.cpp')),c.sourceCppSha256);\n assert.equal(sha(path.join(root,'.cache/nwn74/engine-source-a/servers/rendering/renderer_scene_cull.h')),c.sourceHeaderSha256);");
rep("engineSha256:staged.engine.sha256,captureSha256", "engineSha256:'07d0989649b6b4722921cca2d0ce2960cfe8b732e012a9a8dfda134a8f96afe5',pairIndexMode:mode,captureSha256");
rep("Godot_nwn74_render_probe_b_win64", "Godot_nwn74_pair_index_c_win64");
fs.writeFileSync(target,code,{flag:'wx'});console.log(JSON.stringify({sourceSha256:sha(original),targetSha256:sha(fs.readFileSync(target)),target}));

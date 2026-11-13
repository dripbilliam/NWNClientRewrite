'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const project=path.resolve(__dirname,'../..'),label=process.argv[2],sha=b=>crypto.createHash('sha256').update(b).digest('hex');assert(/^clock-review-[a-z0-9-]+$/.test(label||''));
(async()=>{
 const directory=path.join(project,'.cache/nwn64',label),proposalFile=path.join(directory,'proposal.json'),proposalBytes=fs.readFileSync(proposalFile),proposal=JSON.parse(proposalBytes),output=path.join(directory,'staged.json');assert(!fs.existsSync(output));
 const globals=['tools/native-production-selection.cjs','tools/native-performance-runtime.cjs','.cache/native-kernel/nwn-particle-kernel.dll','.tools/native-core/Godot_native_core_e_win64.exe'].map(relative=>({relative,sha256:sha(fs.readFileSync(path.join(project,relative)))}));
 assert.equal(sha(fs.readFileSync(proposal.preferences.file)),proposal.preferences.sha256);const preferences=JSON.parse(fs.readFileSync(proposal.preferences.file)),selections=[];
 for(const view of proposal.views){
  for(const pin of view.pins)assert.equal(sha(fs.readFileSync(path.join(view.project,pin.relative))),pin.sha256,'Private input changed: '+pin.relative);
  const helper=require(view.selectionHelper),row=await helper.stageProductionSelection({project:view.project,label:label+'-'+view.mode,argv:proposal.argv,preferenceSeeds:preferences,env:{}});
  assert(row.selection.private===true&&row.selection.accepted===false&&row.selection.production===false&&row.selection.kind==='private-unaccepted-clock-review-selection');
  const readback=await helper.readProductionSelection(row.file,row.sha256);assert(readback.evidence.private&&readback.evidence.production===false&&readback.evidence.accepted===false);
  const original=helper.configuration(view.project,proposal.argv,{env:{}});assert.equal(original.renderCore.flags.length,16);assert.equal(original.render.environment.NWN_PARTICLE_PRESENTATION,'shared');assert.equal(original.render.environment.NWN_PARTICLE_LIGHTING,'pooled');
  let globalRejected=false;try{await require(path.join(project,'tools/native-production-selection.cjs')).readProductionSelection(row.file,row.sha256);}catch(error){assert(/Production selection policy differs/.test(error.message));globalRejected=true;}assert(globalRejected,'Global selector must reject private selection');
  for(const pin of view.pins)assert.equal(sha(fs.readFileSync(path.join(view.project,pin.relative))),pin.sha256,'Private input changed during stage');
  selections.push({mode:view.mode,file:row.file,sha256:row.sha256,driver:view.driver,source:row.selection.sourceProject,engine:row.selection.engine,flags:row.selection.flags,environment:row.selection.environment,private:true,accepted:false,production:false,globalSelectorRejected:true,profiling:row.selection.profiling});
 }
 for(const pin of globals)assert.equal(sha(fs.readFileSync(path.join(project,pin.relative))),pin.sha256,'Global artifact changed during private staging');
 const result={issue:'NWN-64',private:true,accepted:false,production:false,proposal:proposalFile,proposalSHA256:sha(proposalBytes),selections,globals,globalArtifactsUnchanged:true,noEngineStarts:true,noNativeBuilds:true,capture:proposal.capture,scope:'Explicit private/unaccepted normal-gameplay clock review. Both local private readers verify exact DLL/CoreE/source provenance; unchanged global production reader rejects both private selections.'};
 fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({file:output,sha256:sha(fs.readFileSync(output)),selections:selections.map(row=>({mode:row.mode,file:row.file,sha256:row.sha256,production:row.production,globalSelectorRejected:row.globalSelectorRejected}))}));
})().catch(error=>{console.error(error.stack);process.exitCode=1;});

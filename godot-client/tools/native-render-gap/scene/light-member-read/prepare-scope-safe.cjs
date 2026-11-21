'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const project=path.resolve(__dirname,'../../../..'),directory=path.join(project,'.cache/native-render-gap/scene/light-member-read-c'),baseFile=path.join(project,'.cache/native-render-gap/scene/light-member-read-b/manifest.json'),base=JSON.parse(fs.readFileSync(baseFile)),sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');if(fs.existsSync(directory))throw Error('Retain prior C proposal');for(const item of base.files)assert.equal(sha(fs.readFileSync(item.file)),item.sha256);
let cpp=fs.readFileSync(base.files[0].file,'utf8');const header=fs.readFileSync(base.files[1].file,'utf8');
function once(from,to){assert.equal(cpp.split(from).length,2,from.slice(0,140));cpp=cpp.replace(from,()=>to);}
once('Node3D *node=node_from_id(id);bool eligible=node!=nullptr;Variant props;GDScriptInstance *plain=nullptr;\n  auto guarded_callback=[&]()->String {++lifetime_post_checks;return callback_boundary(id);};',
`Node3D *node=node_from_id(id);bool eligible=node!=nullptr;Variant props,state;GDScriptInstance *plain=nullptr;
  bool may_release_authored=false;
  auto guarded_callback=[&]()->String {may_release_authored=true;++lifetime_post_checks;return callback_boundary(id);};
  auto release_row_locals=[&]()->String {
   if(!lifetime_guarded||!may_release_authored)return String();
   // A pure canonical row still has Dict/Dict owners in its current instance
   // and a committed row owner in the map. Opaque boundaries can detach them.
   // Release all detached locals outside any map/Entry/Node access, then check
   // before the next order lookup. The Entry reference is not used afterward.
   end_plain_segment();props=Variant();state=Variant();staged_entry.reset();
   ++lifetime_post_checks;return callback_boundary(id);
  };`);
once('else{props=node->get(props_name);error=callback_boundary(id);','else{if(lifetime_guarded)may_release_authored=true;props=node->get(props_name);error=callback_boundary(id);');
once('else{state=node->get(state_name);error=callback_boundary(id);','else{if(lifetime_guarded)may_release_authored=true;state=node->get(state_name);error=callback_boundary(id);');
once('else{revision_value=node->get(revision_name);error=callback_boundary(id);','else{if(lifetime_guarded)may_release_authored=true;revision_value=node->get(revision_name);error=callback_boundary(id);');
once('  Variant state;\n  if(plain){','  if(plain){');
once('error=commit_entry();if(!error.is_empty())return failure(error);continue;}','error=commit_entry();if(!error.is_empty())return failure(error);error=release_row_locals();if(!error.is_empty())return failure(error);continue;}');
once('entry.published=true;error=commit_entry();if(!error.is_empty())return failure(error);if(changed){rows.append(entry.row);++rows_now;}else ++reused_now;',
'entry.published=true;error=commit_entry();if(!error.is_empty())return failure(error);if(changed){rows.append(entry.row);++rows_now;}else ++reused_now;\n  error=release_row_locals();if(!error.is_empty())return failure(error);');
fs.mkdirSync(path.join(directory,'engine-module'),{recursive:true});const files=[];for(const [index,name,text]of [[0,'light_input_registry.cpp',cpp],[1,'light_input_registry.h',header]]){const file=path.join(directory,'engine-module',name);fs.writeFileSync(file,text,{flag:'wx'});files.push({relative:base.files[index].relative,original:base.files[index].file,originalSha256:base.files[index].sha256,file,sha256:sha(Buffer.from(text))});}
const manifest={...base,created:new Date().toISOString(),directory,base:{file:baseFile,sha256:sha(fs.readFileSync(baseFile)),preserved:true},files,scope:base.scope+' C additionally releases detached row-local props/state/staged Entry before next iteration after any opaque boundary and validates registry/Node. Pure quiet canonical containers retain current-instance/map owners and keep the one-proof segment.',runtimeExecuted:false};fs.writeFileSync(path.join(directory,'manifest.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({directory,files:files.map(({relative,sha256})=>({relative,sha256})),runtimeExecuted:false}));

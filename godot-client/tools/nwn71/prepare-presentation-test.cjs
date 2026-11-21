'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),arg=n=>process.argv.find(x=>x.startsWith('--'+n+'='))?.slice(n.length+3),label=arg('label'),source=arg('source');
if(!label||!/^[a-z0-9-]+$/.test(label)||!source||!/^[a-z0-9-]+$/.test(source))throw Error('Fresh --label and pinned --source required');
const output=path.join(root,'.cache/nwn71/presentation-test-'+label),input=path.join(root,'.cache/nwn71/presentation-source-'+source);if(fs.existsSync(output))throw Error('Preserve existing fixture');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex'),inputs=[],seen=new Set();
function write(file,bytes){const dest=path.join(output,file);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,bytes,{flag:'wx'});inputs.push({file,sha256:sha(bytes)});}
function copy(file,bytes=fs.readFileSync(path.join(root,file))){if(seen.has(file))return;seen.add(file);write(file,bytes);for(const match of bytes.toString().matchAll(/(?:preload|load)\("res:\/\/([^"\n]+)"\)/g)){if(match[1].endsWith('.gd')&&!seen.has(match[1]))copy(match[1]);}}
// Seed generated scripts before following their references from the fixture.
copy('tests/nwn71_loading_screen_original.gd',fs.readFileSync(path.join(input,'before/systems/native_loading_screen.gd')));
copy('tests/nwn71_loading_screen_candidate.gd',fs.readFileSync(path.join(input,'after/tests/nwn71_loading_screen_candidate.gd')));
copy('tests/nwn71_presentation_fence_test.gd');
write('project.godot','config_version=5\n[application]\nconfig/name="NWN71 Private Presentation Fence"\n[display]\nwindow/size/viewport_width=800\nwindow/size/viewport_height=600\n');
write('.godot/global_script_class_cache.cfg','list=[]\n');
write('fixture-receipt.json',JSON.stringify({schema:'nwn71-presentation-lifecycle-v1',source:JSON.parse(fs.readFileSync(path.join(input,'source-receipt.json'))),inputs,sharedEdits:0},null,2)+'\n');
console.log(JSON.stringify({view:path.relative(root,output).replaceAll('\\','/'),files:inputs.length}));

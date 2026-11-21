// Writes a private candidate and exact backup only. Never edits/builds an engine.
import fs from 'node:fs/promises';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';import {spawnSync} from 'node:child_process';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),[label]=process.argv.slice(2),hash=v=>crypto.createHash('sha256').update(v).digest('hex');
if(!/^image-atlas-engine-proposal-v[0-9]+$/.test(label??''))throw Error('Fresh bounded proposal label required');
const relative='modules/text_server_adv/text_server_adv.cpp',original=path.join(project,'.cache/native-140fps/render-agent/engine-builtin-light-v2/source',relative),folder=path.join(project,'.cache/native-presentation-parity/particles-agent',label);
const raw=await fs.readFile(original),text=raw.toString('utf8'),newline=text.includes('\r\n')?'\r\n':'\n',needle='if (tex.texture.is_null()) {';let count=0;
// Limit all changes to the four dirty glyph atlas upload paths. The public
// set_texture_image API and rendering/storage/thread policy remain untouched.
const changed=text.replace(/(\t+)(if \(tex\.texture\.is_null\(\)\) \{)/g,(_,indent,code)=>{
 count++;return (indent+'// The render queue must own an immutable Image wrapper, not the\n'+indent+'// atlas object which subsequent glyph rasterization mutates.\n'+indent+'// Image::_duplicate shares byte COW storage until the next write.\n'+indent+'if (img == tex.image) {\n'+indent+'\timg = img->duplicate();\n'+indent+'}\n'+indent+code).replace(/\n/g,newline);
});
if(count!==4||!changed.includes(needle))throw Error('Expected exactly four original glyph upload paths');
await fs.mkdir(folder,{recursive:false});await fs.writeFile(path.join(folder,'text_server_adv.before.cpp'),raw,{flag:'wx'});await fs.writeFile(path.join(folder,'text_server_adv.candidate.cpp'),changed,{flag:'wx'});
const diff=spawnSync('git',['diff','--no-index','--',path.join(folder,'text_server_adv.before.cpp'),path.join(folder,'text_server_adv.candidate.cpp')],{encoding:'utf8',windowsHide:true});if(diff.status!==1)throw Error('Expected exactly a candidate-only diff');
const patch=diff.stdout.replace(/^diff --git .*$/m,'diff --git a/'+relative+' b/'+relative).replace(/^--- .*$/m,'--- a/'+relative).replace(/^\+\+\+ .*$/m,'+++ b/'+relative);await fs.writeFile(path.join(folder,'font-atlas-upload-snapshot.patch'),patch,{flag:'wx'});
const evidence={version:1,label,original,relative,before_sha256:hash(raw),candidate_sha256:hash(changed),patch_sha256:hash(patch),changed_sites:count,original_unchanged:hash(await fs.readFile(original))===hash(raw),engine_builds:0,engine_changes:0,implementation_status:'Proposal only; no compiled-engine validation',reason:'Separate queue holds Ref<Image>; producer must detach mutable atlas Image before submission',files:['text_server_adv.before.cpp','text_server_adv.candidate.cpp','font-atlas-upload-snapshot.patch']};
await fs.writeFile(path.join(folder,'proposal.json'),JSON.stringify(evidence,null,2),{flag:'wx'});console.log(JSON.stringify({folder,...evidence}));

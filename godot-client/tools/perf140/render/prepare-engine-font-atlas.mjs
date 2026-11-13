import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const [label='engine-font-atlas-v1']=process.argv.slice(2);
if(!/^[a-z0-9-]+$/.test(label))throw Error('Explicit private label required');
const base=path.join(project,'.cache/native-140fps/render-agent'),stage=path.join(base,label);
if(fs.existsSync(stage))throw Error('Retain earlier engine stages');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),fileHash=f=>hash(fs.readFileSync(f));
const parentFolder=path.join(base,'engine-builtin-light-v2'),parentFile=path.join(parentFolder,'manifest.json');
const parent=JSON.parse(fs.readFileSync(parentFile)),descriptorFile=path.join(parentFolder,'engine-descriptor.json'),descriptor=JSON.parse(fs.readFileSync(descriptorFile));
if(fileHash(descriptorFile)!=='0f640f95b3ffc2a0a2cf65695004ea5c77eae36718a6a43ae87199578902991e'||descriptor.engines.candidate.sha256!=='ce2d36407d0a6107a3076a00faf7d9f9dae185c86994ccea8dfd7e450c50f12a'||fileHash(descriptor.engines.candidate.path)!==descriptor.engines.candidate.sha256)throw Error('Exact ce2d baseline changed');
for(const pin of parent.modulePins)if(fileHash(path.join(parent.moduleDirectory,pin.relative))!==pin.sha256)throw Error('Parent light module changed');
for(const module of parent.inheritedModules)for(const pin of module.pins)if(fileHash(path.join(module.directory,pin.relative))!==pin.sha256)throw Error('Parent snapshot module changed');
for(const guard of parent.guards)if(fileHash(guard.path)!==guard.sha256)throw Error('Shared/retained guard changed');
const relative='modules/text_server_adv/text_server_adv.cpp',original=path.join(parent.source,relative),before=fs.readFileSync(original,'utf8');
const anchor='hb_font_funcs_t *TextServerAdvanced::funcs = nullptr;';
if(before.split(anchor).length!==2)throw Error('Helper insertion anchor changed');
const newline=before.includes('\r\n')?'\r\n':'\n';
const helper=[
'namespace {',
'// RenderingServer may queue the upload. Keep the canonical glyph atlas mutable,',
'// but give each actual publication its own Image object and COW byte ownership.',
'// Null/empty inputs retain the existing downstream validation/error behavior.',
'Ref<Image> font_atlas_upload_snapshot(const Ref<Image> &p_image) {',
'\tif (p_image.is_null() || p_image->is_empty()) {',
'\t\treturn p_image;',
'\t}',
'\treturn Image::create_from_data(p_image->get_width(), p_image->get_height(), p_image->has_mipmaps(), p_image->get_format(), p_image->get_data());',
'}',
'} // namespace',
'',
].join(newline);
if((before.match(/ImageTexture::create_from_image\(img\)/g)??[]).length!==5||(before.match(/tex\.texture->update\(img\)/g)??[]).length!==4)throw Error('Expected nine atlas upload sites');
const after=before.replace(anchor,helper+anchor).replaceAll('ImageTexture::create_from_image(img)','ImageTexture::create_from_image(font_atlas_upload_snapshot(img))').replaceAll('tex.texture->update(img)','tex.texture->update(font_atlas_upload_snapshot(img))');
const source=path.join(stage,'source');fs.mkdirSync(stage,{recursive:true});
// Real copies, including reusable build objects. No retained source/object is linked.
fs.cpSync(parent.source,source,{recursive:true,preserveTimestamps:true,force:false,errorOnExist:true});
if(fileHash(path.join(source,relative))!==hash(Buffer.from(before)))throw Error('Copied text server changed');
fs.writeFileSync(path.join(stage,'text_server_adv.cpp.before'),before);
fs.writeFileSync(path.join(stage,'text_server_adv.cpp.after'),after);
fs.writeFileSync(path.join(source,relative),after);
const moduleDirectory=path.join(source,path.relative(parent.source,parent.moduleDirectory));
const inheritedModules=parent.inheritedModules.map(m=>({...m,directory:path.join(source,path.relative(parent.source,m.directory))}));
const guards=[...parent.guards,{path:descriptor.engines.candidate.path,sha256:descriptor.engines.candidate.sha256,kind:'ce2d-archived-baseline'},{path:descriptorFile,sha256:fileHash(descriptorFile),kind:'ce2d-descriptor'},{path:original,sha256:hash(Buffer.from(before)),kind:'retained-original-atlas-source'}];
const fontPatch={relative,beforeFile:path.join(stage,'text_server_adv.cpp.before'),beforeSha256:hash(Buffer.from(before)),afterFile:path.join(stage,'text_server_adv.cpp.after'),afterSha256:hash(Buffer.from(after)),createSites:5,updateSites:4,canonicalImageReplaced:false,dirtyPolicyChanged:false,textureIdentityPolicyChanged:false};
const manifest={...parent,directory:stage,source,reusedSource:undefined,parentDescriptor:descriptorFile,parentDescriptorSha256:fileHash(descriptorFile),moduleDirectory,inheritedModules,guards,fontPatch,variantDescription:'Exact ce2d engine plus immutable per-upload TextServerAdvanced atlas Image snapshots. Canonical atlas, dirty policy, texture/RID and renderer features unchanged.',baselineRole:'ce2d optional builtin-light baseline, original mutable atlas upload arguments',candidateRole:'same engine with nine actual atlas publication sites snapshotting Image object/COW storage',copyPolicy:'Real copies only; retained engines/source/output unchanged',buildStarted:false};
fs.writeFileSync(path.join(stage,'manifest.json'),JSON.stringify(manifest,null,2),{flag:'wx'});
console.log(JSON.stringify({stage,fontPatch,guards:guards.length,builds:0,engineStarts:0},null,2));

import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url)),project=path.resolve(here,'../../..'),label=process.argv[2];
if(!/^[a-z0-9-]+$/.test(label??''))throw Error('Overlay label required');
const overlay=path.join(project,'.cache/native-render-gap/particles',label),output=path.join(overlay,'parser-project');
if(fs.existsSync(output))throw Error('Previous parser project retained');fs.mkdirSync(output);
const pins=[],done=new Set();
function copy(relative){if(done.has(relative))return;done.add(relative);const source=fs.existsSync(path.join(overlay,relative))?path.join(overlay,relative):path.join(project,relative),bytes=fs.readFileSync(source);const dest=path.join(output,relative);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,bytes);pins.push({relative,source,sha256:crypto.createHash('sha256').update(bytes).digest('hex')});if(/\.(gd|gdshader|gdshaderinc)$/.test(relative))for(const match of bytes.toString('utf8').matchAll(/(?:preload|load)\(\s*["']res:\/\/([^"']+)["']|#include\s*["']res:\/\/([^"']+)["']/g))copy(match[1]??match[2]);}
copy('tests/native_render_gap_scene_boundary_test.gd');copy('tests/native_render_gap_rig_skin_publisher_test.gd');
if(fs.existsSync(path.join(overlay,'tests/native_render_gap_rig_skin_continuation_test.gd')))copy('tests/native_render_gap_rig_skin_continuation_test.gd');
fs.mkdirSync(path.join(output,'.godot'));fs.writeFileSync(path.join(output,'.godot/global_script_class_cache.cfg'),'list=[]\n');
const certificateSource=path.join(project,'.cache/native-140fps/render-agent/engine-font-atlas-ownership-v1/source/thirdparty/certs/ca-bundle.crt'),certificates=fs.readFileSync(certificateSource);fs.writeFileSync(path.join(output,'ca-bundle.crt'),certificates);pins.push({relative:'ca-bundle.crt',source:certificateSource,sha256:crypto.createHash('sha256').update(certificates).digest('hex')});
fs.writeFileSync(path.join(output,'project.godot'),'config_version=5\n[application]\nconfig/name="Private render-gap parser"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n[network]\ntls/certificate_bundle_override="res://ca-bundle.crt"\n');
fs.writeFileSync(path.join(overlay,'parser-project-receipt.json'),JSON.stringify({project:output,pins,engineStarts:0,scope:'Minimal read-only dependency copy for parser checks; no runtime acceptance'},null,2)+'\n');console.log(JSON.stringify({project:output,files:pins.length}));

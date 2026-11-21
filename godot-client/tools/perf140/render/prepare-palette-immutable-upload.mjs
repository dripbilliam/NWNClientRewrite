import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),label=process.argv[2]??'palette-immutable-upload-v1';
if(!/^[a-z0-9-]+$/.test(label))throw Error('Private label required');
const stage=path.join(project,'.cache/native-140fps/render-agent',label);if(fs.existsSync(stage))throw Error('Previous evidence preserved');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const relative='systems/native_render/native_light_palette.gd',source=path.join(project,'.cache/native-140fps/root/scene-direct-slots-fenced-v1/project',relative),bytes=fs.readFileSync(source);
const reference=fs.readFileSync(path.join(project,'.cache/native-140fps/root/lease-scene-diagnostics-v1/project',relative));
if(!bytes.equals(reference))throw Error('Reported failed palette differs from retained census baseline');
let code=bytes.toString('utf8');const newline=code.includes('\r\n')?'\r\n':'\n';
function replace(before,after){before=before.replaceAll('\r\n',newline);after=after.replaceAll('\r\n',newline);if(code.split(before).length!==2)throw Error('Exact palette source boundary changed');code=code.replace(before,after);}
replace('texture=ImageTexture.create_from_image(image)','texture=ImageTexture.create_from_image(upload_snapshot())');
replace('static func flush() -> void:\r\n\tif dirty: texture.update(image); dirty=false; flushes+=1','static func upload_snapshot() -> Image:\r\n\t# A distinct Image object owns immutable COW bytes while RenderingServer\r\n\t# consumes the queued upload. Later canonical set_pixel calls detach.\r\n\treturn Image.create_from_data(image.get_width(),image.get_height(),image.has_mipmaps(),image.get_format(),image.get_data())\r\nstatic func flush() -> void:\r\n\tif not dirty: return\r\n\tvar uploaded_revision:=revision\r\n\ttexture.update(upload_snapshot())\r\n\t# ImageTexture.update emits changed synchronously. Preserve a new owner\r\n\t# publication made by that callback for the following flush.\r\n\tdirty=revision!=uploaded_revision; flushes+=1');
fs.mkdirSync(stage,{recursive:true});fs.writeFileSync(path.join(stage,'native_light_palette.candidate.gd'),code,{flag:'wx'});
const receipt={version:1,label,source,relative,sourceSha256:hash(bytes),candidateSha256:hash(Buffer.from(code)),changes:['Distinct immutable CPU Image for initial ImageTexture creation','Distinct immutable CPU Image for each texture update; same GPU texture','Retain dirty on synchronous changed-callback revision advance'],engineStarts:0,nativeBuilds:0};
fs.writeFileSync(path.join(stage,'manifest.json'),JSON.stringify(receipt,null,2),{flag:'wx'});console.log(JSON.stringify({stage,...receipt}));

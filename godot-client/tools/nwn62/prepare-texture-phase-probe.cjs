'use strict';
// Create a private ResourcePool overlay for a no-FPS diagnostic replay.
// The accepted client source is read but never modified.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');

const root = path.resolve(__dirname, '../..');
const sourcePath = path.join(root, 'systems/native_render/resource_pool.gd');
const outputDir = path.join(root, '.cache/nwn62/texture-phase-probe-a');
const outputPath = path.join(outputDir, 'resource_pool.gd');
const manifestPath = path.join(outputDir, 'manifest.json');
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const sourceBytes = fs.readFileSync(sourcePath);
let source = sourceBytes.toString('utf8').replace(/\r\n/g, '\n');

function replaceOnce(before, after) {
  const start = source.indexOf(before);
  assert(start >= 0, `Source fragment missing: ${before.slice(0, 70)}`);
  assert(source.indexOf(before, start + before.length) < 0, `Source fragment repeated: ${before.slice(0, 70)}`);
  source = source.slice(0, start) + after + source.slice(start + before.length);
}

replaceOnce(
  'var maximum_textures:=512\n',
  'var maximum_textures:=512\nvar texture_probe_seen: Dictionary={}\nvar texture_probe_recreations:=0\nvar texture_probe_max_total_us:=0\nvar texture_probe_rows: Array=[]\n'
);
replaceOnce(
  '\t\tif use_raster_upload_preparation:_take_ready_raster(key)\n\t\treturn textures[key]\n\tvar data: Dictionary = record.value;',
  '\t\tif use_raster_upload_preparation:_take_ready_raster(key)\n\t\treturn textures[key]\n\tvar probe_started_us:=Time.get_ticks_usec()\n\tif texture_probe_seen.has(key):texture_probe_recreations+=1\n\ttexture_probe_seen[key]=true\n\tvar data: Dictionary = record.value;'
);
replaceOnce(
  '\tif mips.size() > 1 and (int(mips.back().width) != 1 or int(mips.back().height) != 1): failure = "Partial native mip chain needs completion before upload"; return null\n\tvar image: Image=null',
  '\tif mips.size() > 1 and (int(mips.back().width) != 1 or int(mips.back().height) != 1): failure = "Partial native mip chain needs completion before upload"; return null\n\tvar probe_image_began_us:=Time.get_ticks_usec()\n\tvar image: Image=null'
);
replaceOnce(
  '\tvar result := ImageTexture.create_from_image(image)\n\tretain("texture",textures,key,result,maximum_textures); stats.textures_created += 1\n\treturn result',
  '\tvar probe_create_began_us:=Time.get_ticks_usec()\n\tvar result := ImageTexture.create_from_image(image)\n\tvar probe_retain_began_us:=Time.get_ticks_usec()\n\tretain("texture",textures,key,result,maximum_textures); stats.textures_created += 1\n\tvar probe_done_us:=Time.get_ticks_usec()\n\tvar probe_total_us:=probe_done_us-probe_started_us\n\ttexture_probe_max_total_us=maxi(texture_probe_max_total_us,probe_total_us)\n\tif probe_total_us>=500 and texture_probe_rows.size()<256:\n\t\ttexture_probe_rows.append({"sha256":key,"width":width,"height":height,"format":str(data.format),"mips":mips.size(),"prepared":use_raster_upload_preparation,"validation_us":probe_image_began_us-probe_started_us,"image_us":probe_create_began_us-probe_image_began_us,"create_us":probe_retain_began_us-probe_create_began_us,"retain_us":probe_done_us-probe_retain_began_us,"total_us":probe_total_us})\n\treturn result'
);
replaceOnce(
  '\tstate.limits={"templates":maximum_templates,"meshes":maximum_meshes,"textures":maximum_textures,"materials":maximum_materials}\n',
  '\tstate.limits={"templates":maximum_templates,"meshes":maximum_meshes,"textures":maximum_textures,"materials":maximum_materials}\n\tstate.texture_phase_probe={"unique_miss_keys":texture_probe_seen.size(),"recreations":texture_probe_recreations,"max_total_us":texture_probe_max_total_us,"slow_rows":texture_probe_rows.duplicate(true)}\n'
);

assert(!fs.existsSync(outputPath) && !fs.existsSync(manifestPath), 'Private probe output already exists');
fs.mkdirSync(outputDir, {recursive: true});
const output = Buffer.from(source);
fs.writeFileSync(outputPath, output, {flag: 'wx'});
const manifest = {
  issue: 'NWN-62', private: true, accepted: false,
  source: path.relative(root, sourcePath).replaceAll('\\', '/'),
  sourceSha256: hash(sourceBytes),
  overlay: path.relative(root, outputPath).replaceAll('\\', '/'),
  overlaySha256: hash(output),
  scope: 'Only texture cache misses; separates validation, Image construction, ImageTexture creation and cache retention. Diagnostic rows start at 0.5 ms and cap at 256. Not an FPS build.'
};
fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n', {flag: 'wx'});
console.log(JSON.stringify(manifest, null, 2));

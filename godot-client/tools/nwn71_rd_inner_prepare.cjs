// Prepare a private Tracy-only RD attribution proposal. This never edits the
// engine source supplied as input; every anchor must match exactly once.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const [sourceRoot, outputRoot] = process.argv.slice(2);
if (!sourceRoot || !outputRoot) throw new Error('usage: node nwn71_rd_inner_prepare.cjs engine_source output_root');
const targets = [
  {
    relative: 'servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp',
    header: '#include "render_forward_clustered.h"',
    methods: [
      ['_render_scene', 'scene_body'],
      ['_setup_environment', 'environment'],
      ['_fill_render_list', 'fill_render_list'],
      ['_render_list_with_draw_list', 'draw_list'],
      ['_pre_opaque_render', 'pre_opaque'],
      ['_update_dirty_geometry_pipelines', 'dirty_pipelines'],
      ['_setup_lightmaps', 'lightmaps'],
    ],
    owner: 'RenderForwardClustered',
  },
  {
    relative: 'servers/rendering/renderer_rd/renderer_scene_render_rd.cpp',
    header: '#include "renderer_scene_render_rd.h"',
    methods: [
      ['_render_buffers_post_process_and_tonemap', 'tonemap_post'],
      ['_process_compositor_effects', 'compositor_effects'],
    ],
    owner: 'RendererSceneRenderRD',
  },
];
const sha = data => crypto.createHash('sha256').update(data).digest('hex');
const receipt = {scope:'Private GODOT_USE_TRACY function-entry zones to partition the 66.364 ms render_scene_rd interval. No production source, build or performance claim.', files:[]};
for (const target of targets) {
  const source = path.join(sourceRoot, target.relative);
  let data = fs.readFileSync(source, 'utf8');
  const before = sha(data); const newline = data.includes('\r\n') ? '\r\n' : '\n';
  const include = '#include "core/profiling/profiling.h"';
  if (data.includes(include)) throw new Error('Unexpected existing profiling include: '+source);
  if (data.split(target.header).length !== 2) throw new Error('Header anchor missing or repeated: '+source);
  data = data.replace(target.header, target.header+newline+include);
  for (const [method,label] of target.methods) {
    const regex = new RegExp('^(?:void|uint32_t|RID) '+target.owner+'::'+method+'\\([^\\r\\n]*\\) \\{', 'gm');
    const matches = [...data.matchAll(regex)];
    if (matches.length !== 1) throw new Error(method+' expected once in '+source+', found '+matches.length);
    const id = 'nwn71_rd_'+label;
    const zone = newline+'#if defined(GODOT_USE_TRACY)'+newline+'\tZoneNamedN('+id+', "NWN71/RD/'+label+'", true);'+newline+'#endif';
    data = data.replace(regex, m => m+zone);
  }
  const output = path.join(outputRoot, target.relative);
  fs.mkdirSync(path.dirname(output),{recursive:true});
  fs.writeFileSync(output,data);
  receipt.files.push({relative:target.relative,source_sha256:before,proposal_sha256:sha(data),zones:target.methods.map(x=>'NWN71/RD/'+x[1])});
}
fs.writeFileSync(path.join(outputRoot,'receipt.json'),JSON.stringify(receipt,null,2)+'\n');

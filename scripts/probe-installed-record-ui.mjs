import fs from 'node:fs/promises';
import {openLocalModule} from './local-module.mjs';
import {parseModel} from '../src/model_parser.js';
import {buildUiModel} from '../src/native_ui_assets.js';
import {RESOURCE_TYPE,decodeResourceText} from '../src/resource_archive.js';
import {parse2da} from '../src/area.js';
const root=await openLocalModule('../FullDecomp/NwnRootInstall','../FullDecomp/NwnRootInstall/data/nwm/Prelude.nwm'),models={};
for(const name of ['pnl_chrsht','pnl_chrsht_char','pnl_chrsht_char2','pnl_chrsht_skils','ctl_chrsht_desc','ctl_chr_btnlstbx','ctl_chr_btn_skil','ctl_chr_btn_feat','pnl_inv','ctl_inv_slot']){
 try{const model=parseModel(await root.getResource(name,RESOURCE_TYPE.MDL)),ui=buildUiModel(model);models[name]={bounds:{min:ui.bounds.min.toArray(),max:ui.bounds.max.toArray()},hooks:Object.fromEntries(ui.hooks),animations:model.animations.map(a=>a.name)};ui.root.traverse(o=>{o.geometry?.dispose();o.material?.dispose();});}catch(e){models[name]={error:e.message};}
}
const columns={};for(const name of ['feat','skills','baseitems']){const t=parse2da(decodeResourceText(await root.getResource(name,RESOURCE_TYPE.TWO_DA)));columns[name]=t.columns;}
await fs.writeFile('backups/animations/installed-record-ui-hooks-v1.json',JSON.stringify({scope:'Derived layout hooks/bounds/animation names only; installed assets remain external.',models,columns},null,2));console.log(JSON.stringify(Object.fromEntries(Object.entries(models).map(([name,v])=>[name,v.error??v.bounds]))));

import {openLocalModule} from './local-module.mjs';
import {parseGff} from '../src/gff.js';
import {parseModel} from '../src/model_parser.js';
import {buildUiModel} from '../src/native_ui_assets.js';
const root='../FullDecomp/NwnRootInstall',resolver=await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`);
for(const name of ['inv_container']){const layout=parseGff(await resolver.getResource(name,2047),'GUI ').root;console.log(JSON.stringify({resource:name,layout}));}
for(const name of ['pnl_container','inv_box_7x5','ctl_btn_ctr','ctl_inv_con_lbl']){const model=parseModel(await resolver.getResource(name,2002)),ui=buildUiModel(model);console.log(JSON.stringify({model:name,bounds:{min:ui.bounds.min.toArray(),max:ui.bounds.max.toArray()},hooks:[...ui.hooks],nodes:model.nodes.map(n=>({name:n.name,type:n.type,position:n.position,bitmap:n.bitmap,parent:n.parent}))}));}

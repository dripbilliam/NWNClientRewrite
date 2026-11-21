// Read-only installed UI/rules metadata; no asset bytes are exported.
import {openLocalModule} from './local-module.mjs';
import {RESOURCE_TYPE,decodeResourceText} from '../src/resource_archive.js';
import {parseGff} from '../src/gff.js';
import {parse2da} from '../src/area.js';
import {parseModel} from '../src/model_parser.js';
import {buildUiModel} from '../src/native_ui_assets.js';
const [install,modulePath]=process.argv.slice(2),resolver=await openLocalModule(install,modulePath);
const names=[...resolver.key.resources.keys()].filter(key=>/^(actions|gui_actionqueue|ctl_actionqueue|pnl_actionqueue):/.test(key));console.log(JSON.stringify({resourceNames:names}));
for(const key of names){const [name,type]=key.split(':');
  if(Number(type)===RESOURCE_TYPE.TWO_DA){const table=parse2da(decodeResourceText(await resolver.getResource(name,RESOURCE_TYPE.TWO_DA)));console.log(JSON.stringify({name,rowCount:table.orderedRows.length,actions:table.orderedRows.map((row,index)=>({index,label:row.LABEL,stringRef:row.STRING_REF,icon:row.ICONRESREF}))}));}
  if(Number(type)===RESOURCE_TYPE.GUI){const root=parseGff(await resolver.getResource(name,RESOURCE_TYPE.GUI),'GUI ').root;console.log(JSON.stringify({name,controlCount:root.Controls?.length??0}));}
  if(Number(type)===RESOURCE_TYPE.MDL){const parsed=parseModel(await resolver.getResource(name,RESOURCE_TYPE.MDL)),ui=buildUiModel(parsed);console.log(JSON.stringify({name,bounds:{min:ui.bounds.min.toArray(),max:ui.bounds.max.toArray()},hooks:[...ui.hooks],bitmaps:[...new Set(parsed.nodes.map(node=>node.bitmap).filter(Boolean))]}));}
}

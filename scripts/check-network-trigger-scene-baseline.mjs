// Compare the pre-existing equipment-count assertion without editing live
// source or changing any installed asset. Both branches use the same capture.
import fs from 'node:fs';import {pathToFileURL,fileURLToPath} from 'node:url';
import {NetworkScene} from '../src/network_scene.js';import {NetworkWorld} from '../src/network_world.js';import {openLocalModule} from './local-module.mjs';import {parseModel} from '../src/model_parser.js';import {createModelHierarchy} from '../src/model_hierarchy.js';
try{
 const root=fileURLToPath(new URL('../',import.meta.url));
 let source=fs.readFileSync(root+'src/network_scene.js','utf8').replace("import {syncNetworkTriggerSurface,pickNetworkTriggerSurfaces} from './network_trigger_surface.js';",'').replace('   if(object.objectType===7){syncNetworkTriggerSurface(this,object);continue;}','').replace('this.root.updateWorldMatrix(true,true);const visible=pickNetworkTriggerSurfaces(this,raycaster,pickedWorldObject(raycaster,this.root,picks,{includePlayer}));','const visible=pickedWorldObject(raycaster,this.root,picks,{includePlayer});');
 source=source.replace(/from '\.\/([^']+)'/g,(_match,name)=>"from '"+pathToFileURL(root+'src/'+name).href+"'").replace("from 'three'","from '"+import.meta.resolve('three')+"'");
 const Baseline=(await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'))).NetworkScene,capture=JSON.parse(fs.readFileSync(root+'backups/animations/local-network-session-v1.json','utf8')),install=root+'../FullDecomp/NwnRootInstall',resolver=await openLocalModule(install,install+'/data/nwm/Prelude.nwm'),results=[];
 for(const [label,Type]of [['without-trigger-change',Baseline],['with-trigger-change',NetworkScene]]){
  const world=new NetworkWorld();for(const m of capture.messages)world.apply(m);const area=capture.messages.find(m=>m.kind==='client-area').area,scene=new Type({world,resolver,report:()=>{},loadAsset:async(name,r)=>({model:parseModel(await r.getResource(name,2002))}),instantiate:asset=>({root:createModelHierarchy(asset.model).root,dispose(){}}),releaseAsset(){}});
  try{await scene.loadArea(area);results.push({label,objects:scene.snapshot().objects.length,playerModels:scene.objects.get(0xffffffff).models.length});}finally{await scene.dispose();}
 }
 console.log(JSON.stringify(results));fs.writeFileSync(root+'backups/animations/network-trigger-existing-scene-baseline-v1.json',JSON.stringify(results,null,2)+'\n');
}catch(error){console.error(error.code??error.name,String(error.message).slice(0,180));process.exitCode=1;}

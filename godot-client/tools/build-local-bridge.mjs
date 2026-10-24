import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {build} from 'vite';
import {isolateVisualDelivery} from './isolate-visual-delivery.mjs';
import {isolatePltCompatibility} from './plt-compatibility.mjs';
import {isolateAudio} from './isolate-audio.mjs';

const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),root=path.dirname(project);
const version=process.argv.find(a=>a.startsWith('--version='))?.slice(10);
if(!/^v[1-9][0-9]*$/.test(version??''))throw Error('Use a new --version=vN');
const out=path.join(project,'.cache/local-bridge',version),main=path.join(root,'src/main.js'),sceneSource=path.join(root,'src/network_scene.js');
try{await fs.access(out);throw Error('Build exists; choose a new version');}catch(e){if(e.code!=='ENOENT')throw e;}
const pltSource=path.join(root,'src/bioware_plt.js');
const hash=data=>createHash('sha256').update(data).digest('hex'),before=hash(await fs.readFile(main)),sceneBefore=hash(await fs.readFile(sceneSource)),pltBefore=hash(await fs.readFile(pltSource));let edits=0,visualEdits=0,pltEdits=0;
await build({root,configFile:false,base:'./',envDir:false,envPrefix:[],plugins:[{name:'godot-local-resource-staging',enforce:'pre',transform(code,id){
 if(path.resolve(id.split('?')[0])===pltSource){pltEdits++;return{code:isolatePltCompatibility(code),map:null};}
 if(path.resolve(id.split('?')[0])===sceneSource){visualEdits++;return{code:isolateVisualDelivery(code),map:null};}
 if(path.resolve(id.split('?')[0])!==main)return null;
 code="import {SilentAudio} from '/godot-client/tools/silent-audio.mjs';\n"+isolateAudio(code);
 const site='renderer.setAnimationLoop(() => {';if(code.split(site).length!==2)throw Error('Frame ownership boundary changed');edits++;
 code=code.replace(site,'let godotStagingFrame; renderer.setAnimationLoop(godotStagingFrame=() => {');
 const areaLight='sceneLighting.add(sunlight, sunlight.target);';if(code.split(areaLight).length!==2)throw Error('Native area light staging boundary changed');
 code=code.replace(areaLight,'sunlight.userData.nativeAreaLight=true; '+areaLight);
 return{code:"import {createCreationPreviewStaging} from '/godot-client/tools/staging-creation-preview.mjs';\nimport {createAreaStaging} from '/godot-client/tools/staging-area.mjs';\nimport {isolateLobby} from '/godot-client/tools/isolate-lobby.mjs';\nimport {createContentStaging} from '/godot-client/tools/staging-content.mjs';\nimport {createDriveStaging} from '/godot-client/tools/drive-staging.mjs';\nimport {createVisualModelStaging} from '/godot-client/tools/staging-visual-model.mjs';\nimport {createVisualDefinitionStaging} from '/godot-client/tools/staging-visual-definition.mjs';\nimport {networkPortrait as godotPortrait} from '/src/network_portrait.js';\nimport {GameCursorAssets as GodotCursorAssets} from '/src/game_cursor.js';\n"+code+`
isolateLobby(networkFrontend);
const godotContent=createContentStaging({scene,camera,presentation:()=>networkPresentation,frontend:networkFrontend});
const godotCursors=new WeakMap();
let godotCreationAssets=null,godotCreationOwner=null;
const godotCreationPreview=createCreationPreviewStaging({frontend:networkFrontend,resource:(id,...args)=>nativeNetwork.getResource(id,...args),textureResource:(id,name)=>nativeNetwork.getTextureResource(id,name),loadTextures,buildObject,findObjectByName,createModelAnimator});
const godotVisualResource=createVisualModelStaging({presentation:()=>networkPresentation,frontend:networkFrontend});
window.godotLocalStaging={
 nativeSelectionOwner:()=>networkFrontend.lobby===null,
 content:godotContent,
 visualModel:godotVisualResource,
 visualDefinition:createVisualDefinitionStaging({presentation:()=>networkPresentation,frontend:networkFrontend,resource:godotVisualResource}),
 drive:createDriveStaging({presentation:()=>networkPresentation,frontend:networkFrontend}),
 portrait:async row=>godotPortrait(networkQuickbar.assets,row.portrait<0xfffe?{portraits:await networkExamine.table('portraits')}:{},row,row.size??3,{crop:true}),
 creationPreview:godotCreationPreview,
 creationPortrait:async row=>{const owner=networkFrontend.id;if(!owner)return null;if(owner!==godotCreationOwner){godotCreationOwner=owner;godotCreationAssets={resolver:{getResource:(...args)=>nativeNetwork.getResource(owner,...args),getTextureResource:name=>nativeNetwork.getTextureResource(owner,name)}};}const image=await godotPortrait(godotCreationAssets,{}, {portrait:65534,portraitRef:row.reference},3,{crop:true});return owner===networkFrontend.id?image:null;},
 icon:name=>networkQuickbar.icon(name),
 mapArt:async row=>{const assets=networkQuickbar.assets;if(!assets)throw Error('Installed map assets are unavailable');return row.kind==='tile'?assets.mapTileSkin(row.reference,row.orientation):assets.skin(row.reference,row.state);},
 nuiImage:(name,region)=>recordNuiImage(name,region),
 cursor:id=>{const assets=networkQuickbar.assets;if(!assets)return null;let cursors=godotCursors.get(assets);if(!cursors){cursors=new GodotCursorAssets(assets);godotCursors.set(assets,cursors);}return cursors.get(id);},
 settled:async()=>{await networkFrontend.queue;await networkPresentation?.syncWork;return true;},
 resume:()=>renderer.setAnimationLoop(godotStagingFrame),
 snapshot:()=>({phase:networkFrontend.phase,areaId:networkFrontend.world?.areaId,generation:networkFrontend.areaGeneration,area:networkPresentation?.area?.resRef,objects:networkPresentation?.objects.size??0,models:networkPresentation?.instances.size??0,pending:networkPresentation?.assetPending??0,graphicsPending:Boolean(networkPresentation?.graphicsPending),controlled:networkPresentation?.objects.has(networkFrontend.world?.localObjectId)??false,failures:[...(networkPresentation?.failures.keys()??[])]}),
 export:createAreaStaging({scene,camera,presentation:()=>networkPresentation,frontend:networkFrontend,focus:()=>controls.target.toArray(),stop:()=>{renderer.setAnimationLoop(null);if(networkPresentation)networkPresentation.receiveAnimationChanges=()=>{};},content:godotContent})
};
// Native Godot is the sole NUI presenter/input owner in this isolated build.
networkNui.reset();networkNui.sync=()=>{};
`,map:null};
}}],build:{outDir:out,emptyOutDir:false}});
if(edits!==1||visualEdits!==1||pltEdits<1||hash(await fs.readFile(main))!==before||hash(await fs.readFile(sceneSource))!==sceneBefore||hash(await fs.readFile(pltSource))!==pltBefore)throw Error('Source identity check failed');
await fs.writeFile(path.join(project,'.cache/local-bridge/latest.json'),JSON.stringify({version:1,build:out,productionSourceUnchanged:true})+'\n');
console.log(JSON.stringify({out,productionSourceUnchanged:true}));

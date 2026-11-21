import * as T from 'three';import {createRigFixture} from './rig-fixture.mjs';
import {exportCreationPreview} from './staging-creation-preview.mjs';import {preparePreviewBundle,creationPreviewPackets} from './creation-preview.mjs';
export function creationRigFixture(){const f=createRigFixture(),scene=new T.Scene(),models=f.presentation.objects.get(1).models;scene.add(models[0].root);models[1].root.userData.mdlRoot=models[1].model.modelName;f.groups.get('hand').add(models[1].root);scene.updateMatrixWorld(true);return{...f,scene,models};}
export async function authoredCreationPreview(){
 // GLTFExporter needs this browser file adapter even for authored untextured
 // boxes. This CLI fixture never reads installed game content.
 globalThis.FileReader??=class{readAsArrayBuffer(blob){blob.arrayBuffer().then(value=>{this.result=value;this.onloadend?.();});}};
 const f=creationRigFixture(),draft={gender:0,raceId:0,phenotype:0,head:1,clothes:0,skin:0,hair:0,tattoo1:0,tattoo2:0},result=await exportCreationPreview({...f,camera:new T.PerspectiveCamera(),draft});
 f.animator.apply(f.model.animations[0],.25);f.scene.updateMatrixWorld(true);
 const oracle={hand:f.groups.get('hand').matrixWorld.toArray(),part:f.models[1].root.matrixWorld.toArray(),time:.25};
 const bundle=preparePreviewBundle(result,draft);return{scope:'Authored triangle/boxes and original hierarchy/rig math; no installed assets',packets:[{kind:'creation-preview-loading',previewId:1,appearance:draft},...creationPreviewPackets(bundle,1)],metadata:JSON.parse(bundle.manifest),oracle};
}
if(process.argv[1]?.replaceAll('\\','/').endsWith('/creation-preview-fixture.mjs')){const {writeFile}=await import('node:fs/promises'),file=process.argv.find(a=>a.startsWith('--output='))?.slice(9);if(!file)throw Error('Provide --output');const value=await authoredCreationPreview();await writeFile(file,JSON.stringify(value)+'\n',{flag:'wx'});console.log(JSON.stringify({authored:true,meshes:value.metadata.counts.meshes,models:value.metadata.rigs.counts.models,file}));}

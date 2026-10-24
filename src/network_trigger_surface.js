import {BufferGeometry,DoubleSide,Float32BufferAttribute,Group,Mesh,MeshBasicMaterial} from 'three';
import {networkTriggerSurface} from './network_trigger.js';

export function syncNetworkTriggerSurface(scene,object){
 const signature=JSON.stringify([object.replicated?.vertices,Boolean(object.replicated?.hasTransition),Boolean(object.replicated?.isTrap)]),old=scene.objects.get(object.id);
 if(old?.signature===signature)return;
 const surface=networkTriggerSurface(object);if(!surface){scene.remove(object.id);return;}
 scene.remove(object.id);
 const wrapper=new Group();wrapper.name='Transition region';wrapper.userData.worldObjectId=wrapper.userData.networkObjectId=object.id;wrapper.position.fromArray(surface.center);
 const positions=surface.triangles.flatMap(t=>t.flatMap(i=>surface.vertices[i].map((v,j)=>v-surface.center[j]))),geometry=new BufferGeometry();geometry.setAttribute('position',new Float32BufferAttribute(positions,3));geometry.computeVertexNormals();
 // The region is invisible until the highlight renderer selects it. It is
 // authoritative server geometry, not an invented collider or local trigger.
 const material=new MeshBasicMaterial({side:DoubleSide,transparent:true,opacity:0,depthWrite:false,colorWrite:false}),mesh=new Mesh(geometry,material);mesh.userData.nativeTransitionSurface=true;mesh.userData.nativeModelMesh=true;wrapper.add(mesh);
 scene.objects.set(object.id,{wrapper,models:[],held:[],worn:[],signature,animation:null,triggerSurface:surface,disposeTrigger:()=>{geometry.dispose();material.dispose();}});scene.root.add(wrapper);
}
export function pickNetworkTriggerSurfaces(scene,raycaster,visible){
 let nearest=visible;
 for(const [id,binding]of scene.objects){if(!binding.triggerSurface)continue;const object=scene.world.registry.get(id);if(!object||object.replicationRemoved||object.areaId!==scene.area.id)continue;
  const hit=raycaster.intersectObject(binding.wrapper,true)[0];if(hit&&hit.distance<=(nearest?.distance??Infinity)+.01)nearest={object,point:hit.point,distance:hit.distance};
 }
 return nearest;
}

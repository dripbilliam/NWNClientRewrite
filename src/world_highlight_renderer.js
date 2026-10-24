import {AdditiveBlending,Box3,BufferGeometry,Color,DoubleSide,DynamicDrawUsage,Float32BufferAttribute,InstancedMesh,Matrix4,ShaderMaterial,Vector3} from 'three';

const vertexShader=`
varying vec2 highlightUv;
varying vec3 highlightTint;
varying float highlightFacing;
void main(){
 vec4 view = modelViewMatrix * instanceMatrix * vec4(position,1.0);
 vec3 faceNormal = normalize(mat3(modelViewMatrix * instanceMatrix) * normal);
 highlightFacing = pow(abs(dot(faceNormal,normalize(-view.xyz))),2.0);
 highlightUv=uv;
 highlightTint=instanceColor;
 gl_Position=projectionMatrix*view;
}`;
const fragmentShader=`
varying vec2 highlightUv;
varying vec3 highlightTint;
varying float highlightFacing;
uniform float highlightTime;
void main(){
 vec2 p=highlightUv*2.0-1.0;
 float glow=pow(max(0.0,1.0-dot(p,p)),1.4);
 float alpha=glow*highlightFacing*(0.50+0.04*sin(highlightTime*4.0));
 gl_FragColor=vec4(highlightTint,alpha);
 #include <colorspace_fragment>
}`;

function partGeometry(){
 // Original WritePartHighlightVertices uses three textured quads through a
 // part's local bounds. Keep that small geometry in one instanced draw, rather
 // than rendering every model a second time or running a fullscreen outline.
 const positions=[],normals=[],uvs=[],order=[0,1,2,0,2,3],corners=[[-.5,-.5],[.5,-.5],[.5,.5],[-.5,.5]];
 for(let axis=0;axis<3;axis++)for(const index of order){const v=[0,0,0],n=[0,0,0],[a,b]=corners[index];v[(axis+1)%3]=a;v[(axis+2)%3]=b;n[axis]=1;positions.push(...v);normals.push(...n);uvs.push(a+.5,b+.5);}
 const geometry=new BufferGeometry();geometry.setAttribute('position',new Float32BufferAttribute(positions,3));geometry.setAttribute('normal',new Float32BufferAttribute(normals,3));geometry.setAttribute('uv',new Float32BufferAttribute(uvs,2));return geometry;
}
export function highlightMeshVisible(mesh,root){
 if(!mesh.isMesh||!mesh.userData.nativeModelMesh||!mesh.geometry?.attributes.position)return false;
 for(let node=mesh;node;node=node.parent){if(!node.visible)return false;if(node===root)break;}
 return mesh.userData.nativeTransitionSurface||mesh.userData.nativeObjectHitMesh||(Array.isArray(mesh.material)?mesh.material:[mesh.material]).some(m=>m?.visible&&m.opacity>0.01);
}

export class WorldHighlightRenderer{
 constructor(scene){
  this.scene=scene;this.geometry=partGeometry();this.material=new ShaderMaterial({vertexShader,fragmentShader,uniforms:{highlightTime:{value:0}},side:DoubleSide,transparent:true,blending:AdditiveBlending,depthWrite:false,depthTest:false,toneMapped:false});
  this.capacity=0;this.mesh=null;this.bounds=new Box3();this.center=new Vector3();this.size=new Vector3();this.local=new Matrix4();this.matrix=new Matrix4();this.worldBox=new Box3();this.color=new Color();this.parts=0;
 }
 reserve(count){
  if(count<=this.capacity)return;
  this.mesh?.removeFromParent();this.mesh?.dispose();this.capacity=2**Math.ceil(Math.log2(Math.max(32,count)));
  this.mesh=new InstancedMesh(this.geometry,this.material,this.capacity);this.mesh.instanceMatrix.setUsage(DynamicDrawUsage);this.mesh.setColorAt(0,new Color());this.mesh.instanceColor.setUsage(DynamicDrawUsage);this.mesh.name='Object highlights';this.mesh.userData.ignoreWorldPicking=true;this.mesh.raycast=()=>{};this.mesh.frustumCulled=false;this.mesh.renderOrder=5;this.mesh.castShadow=this.mesh.receiveShadow=false;this.scene.add(this.mesh);
 }
 update(entries,time){
  this.parts=0;
  if(!entries.length){if(this.mesh){this.mesh.count=0;this.mesh.visible=false;}return;}
  const count=entries.reduce((n,e)=>n+e.meshes.length,0);
  if(!count){for(const entry of entries){entry.bounds??=new Box3();entry.bounds.makeEmpty();}this.clear();return;}
  this.reserve(count);this.material.uniforms.highlightTime.value=time/1000;
  for(const entry of entries){
   entry.bounds??=new Box3();entry.bounds.makeEmpty();entry.root.updateWorldMatrix(true,true);this.color.set(entry.color);
   for(const source of entry.meshes){
    if(!highlightMeshVisible(source,entry.root))continue;
    const geometry=source.geometry;if(!geometry.boundingBox)geometry.computeBoundingBox();this.bounds.copy(geometry.boundingBox);if(this.bounds.isEmpty())continue;
    this.worldBox.copy(this.bounds).applyMatrix4(source.matrixWorld);entry.bounds.union(this.worldBox);
    this.bounds.getCenter(this.center);this.bounds.getSize(this.size);this.size.multiplyScalar(1.75);this.size.set(Math.max(.07,this.size.x),Math.max(.07,this.size.y),Math.max(.07,this.size.z));
    this.local.makeScale(this.size.x,this.size.y,this.size.z);this.local.setPosition(this.center);this.matrix.multiplyMatrices(source.matrixWorld,this.local);
    this.mesh.setMatrixAt(this.parts,this.matrix);this.mesh.setColorAt(this.parts,this.color);this.parts++;
   }
  }
  this.mesh.count=this.parts;this.mesh.visible=this.parts>0;
  if(this.parts){this.mesh.instanceMatrix.clearUpdateRanges();this.mesh.instanceMatrix.addUpdateRange(0,this.parts*16);this.mesh.instanceMatrix.needsUpdate=true;this.mesh.instanceColor.clearUpdateRanges();this.mesh.instanceColor.addUpdateRange(0,this.parts*3);this.mesh.instanceColor.needsUpdate=true;}
 }
 clear(){this.parts=0;if(this.mesh){this.mesh.count=0;this.mesh.visible=false;}}
 dispose(){this.mesh?.removeFromParent();this.mesh?.dispose();this.geometry.dispose();this.material.dispose();this.mesh=null;this.capacity=0;}
}

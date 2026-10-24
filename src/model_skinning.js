import * as THREE from 'three';
import {multiplyParticleQuaternion,rotateParticleVector,particleQuaternionBasis} from './particle_math.js';

export function updateSkinnedMesh(mesh,vertices){
 const geometry=mesh.geometry,attribute=geometry.getAttribute('position');
 const sources=mesh.userData.sourceVertexIndices;
 for(let index=0;index<sources.length;index++){const vertex=vertices[sources[index]];attribute.setXYZ(index,vertex[0],vertex[1],vertex[2]);}
 attribute.needsUpdate=true;
 updateSkinNormals(geometry,attribute);
 // Box3 diagnostics cache this optional raycast rejection bound. The old
 // pose must not reject hits on newly deformed vertices. Rebuild lazily when
 // a bounds consumer next asks; raycasting can use the fresh sphere meanwhile.
 geometry.boundingBox=null;
 geometry.computeBoundingSphere();
}

// buildMesh expands material-group faces into independent Float32 triangles.
// Match Three's cross -> Float32 normal store -> normalization rounding, while
// avoiding the redundant clear and three identical square roots per triangle.
// Indexed, interleaved or differently encoded data retains Three's own path.
function updateSkinNormals(geometry,position){
 let normal=geometry.getAttribute('normal');
 if(geometry.index||position.isInterleavedBufferAttribute||position.normalized||position.itemSize!==3||position.count%3||!(position.array instanceof Float32Array)||normal&&(normal.isInterleavedBufferAttribute||normal.normalized||normal.itemSize!==3||normal.count!==position.count||!(normal.array instanceof Float32Array))){geometry.computeVertexNormals();return;}
 if(!normal){normal=new THREE.BufferAttribute(new Float32Array(position.count*3),3);geometry.setAttribute('normal',normal);}
 const p=position.array,n=normal.array;
 for(let i=0;i<p.length;i+=9){
  const cbx=p[i+6]-p[i+3],cby=p[i+7]-p[i+4],cbz=p[i+8]-p[i+5],abx=p[i]-p[i+3],aby=p[i+1]-p[i+4],abz=p[i+2]-p[i+5];
  const x=Math.fround(cby*abz-cbz*aby),y=Math.fround(cbz*abx-cbx*abz),z=Math.fround(cbx*aby-cby*abx),inverse=1/(Math.sqrt(x*x+y*y+z*z)||1),nx=x*inverse,ny=y*inverse,nz=z*inverse;
  n[i]=n[i+3]=n[i+6]=nx;n[i+1]=n[i+4]=n[i+7]=ny;n[i+2]=n[i+5]=n[i+8]=nz;
 }
 normal.needsUpdate=true;
}

// ExecuteSkinGPU1400deb90: pose * inverse bind, indexed by physical bone;
// slot indices select those bones. The original mutates temporary bone poses
// and stops at the second root0 slot. Matrices are native row-major here.
export function nativeSkinBoneMatrices(slots,positions,quaternions,inversePositions,inverseQuaternions){
 const p=positions.map(v=>v?.map(Math.fround)),q=quaternions.map(v=>v?.map(Math.fround)),matrices=[];let rootSeen=false;
 for(let slot=0;slot<Math.min(slots.length,64);slot++){
  const index=slots[slot];if(index<0||index>=p.length)continue;
  if(index===0){if(rootSeen)break;rootSeen=true;}
  if(!p[index]||!q[index]||!inversePositions[index]||!inverseQuaternions[index])throw Error('Native skin inverse-bind bone '+index+' is unavailable');
  const offset=rotateParticleVector(q[index],inversePositions[index]);p[index]=p[index].map((v,i)=>Math.fround(v+offset[i]));q[index]=multiplyParticleQuaternion(q[index],inverseQuaternions[index]);
  const b=particleQuaternionBasis(q[index]),t=p[index];matrices[slot]=[b[0],b[3],b[6],t[0],b[1],b[4],b[7],t[1],b[2],b[5],b[8],t[2],0,0,0,1];
 }
 return matrices;
}

// GatherBones/RenderSkinned compose rigid Part poses; per-node scale does not
// enter their bone matrices. Shared model/Gob placement cancels in skin space.
function rigidWorld(group,cache){
 if(cache.has(group))return cache.get(group);
 const matrix=new THREE.Matrix4().compose(group.position,group.quaternion,new THREE.Vector3(1,1,1));if(group.parent)matrix.premultiply(rigidWorld(group.parent,cache));cache.set(group,matrix);return matrix;
}

export function deformSkinnedVertices(node, nodes, groups, skinGroup,nodeGroups=null) {
 if(node.skinData.qboneRefInv&&node.skinData.tboneRefInv){
  const cache=new Map(),inverseSkin=rigidWorld(skinGroup,cache).clone().invert(),positions=Array(nodes.length),quaternions=Array(nodes.length);let rootSeen=false;
  for(const index of node.skinData.boneConstantSlots.slice(0,64)){
   if(index<0||index>=nodes.length)continue;if(index===0){if(rootSeen)break;rootSeen=true;}if(positions[index])continue;
   const source=nodes[index],group=nodeGroups?.get(source)??groups.get(source.name);if(!group)throw Error('Native skin bone Part '+index+' is unavailable');
   const p=new THREE.Vector3(),q=new THREE.Quaternion(),scale=new THREE.Vector3();inverseSkin.clone().multiply(rigidWorld(group,cache)).decompose(p,q,scale);positions[index]=[p.x,-p.z,p.y];quaternions[index]=[q.w,q.x,-q.z,q.y];
  }
  const matrices=nativeSkinBoneMatrices(node.skinData.boneConstantSlots,positions,quaternions,node.skinData.tboneRefInv,node.skinData.qboneRefInv);
  return node.verts.map((vertex,index)=>{
   const output=[0,0,0];let weighted=false;
   for(let component=0;component<4;component++){
    const weight=node.skinData.weights[index][component];if(weight<=0)continue;
    const matrix=matrices[node.skinData.boneIndices[index][component]];if(!matrix)throw Error('Native weighted skin slot is unavailable');weighted=true;
    for(let axis=0;axis<3;axis++){const row=axis*4;output[axis]+=(matrix[row]*vertex[0]+matrix[row+1]*vertex[1]+matrix[row+2]*vertex[2]+matrix[row+3])*weight;}
   }
   const result=weighted?output:vertex;return[result[0],result[2],-result[1]];
  });
 }
 // Legacy decoded-only inputs without reference arrays retain their existing
 // identity-bind contract. Binary models always use the checked path above.
  const inverseSkinMatrix = skinGroup.matrixWorld.clone().invert();
  const boneMatrices = node.skinData.boneConstantSlots.map((nodeIndex) => {
    const boneNode = nodes[nodeIndex];
    if (!boneNode) return null;
    const boneGroup = nodeGroups?.get(boneNode)??groups.get(boneNode.name);
    return boneGroup ? inverseSkinMatrix.clone().multiply(boneGroup.matrixWorld) : null;
  });

  return node.verts.map((vertex, vertexIndex) => {
    const basePosition = new THREE.Vector3(vertex[0], vertex[2], -vertex[1]);
    const skinnedPosition = new THREE.Vector3();
    let totalWeight = 0;

    for (let component = 0; component < 4; component += 1) {
      const weight = node.skinData.weights[vertexIndex][component];
      const matrix = boneMatrices[node.skinData.boneIndices[vertexIndex][component]];
      if (weight <= 0 || !matrix) continue;
      skinnedPosition.add(basePosition.clone().applyMatrix4(matrix).multiplyScalar(weight));
      totalWeight += weight;
    }

    return totalWeight > 0 ? skinnedPosition.toArray() : basePosition.toArray();
  });
}


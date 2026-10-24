// Broad phase only. The exact native f32 polygon kernel still owns crossing,
// edge inclusion, sidedness, normal and nearest-hit order. Keep uncertain,
// nonplanar or poorly conditioned faces on that unfiltered path.
export function cameraFaceBounds(face){
 const {vertices,normal,constant}=face;if(vertices.length!==3||![...vertices.flat(),...normal,constant].every(Number.isFinite))return null;
 const a=vertices[1].map((v,i)=>v-vertices[0][i]),b=vertices[2].map((v,i)=>v-vertices[0][i]),cross=[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]],area=Math.hypot(...cross),length=Math.hypot(...normal),edge=Math.max(a.reduce((n,v)=>n+v*v,0),b.reduce((n,v)=>n+v*v,0));
 if(!(length>1e-8&&area>edge*1e-4)||cross.reduce((n,v,i)=>n+v*normal[i],0)<area*length*.99999)return null;
 const min=[0,1,2].map(i=>Math.min(...vertices.map(v=>v[i]))),max=[0,1,2].map(i=>Math.max(...vertices.map(v=>v[i]))),scale=Math.max(1,...min.map(Math.abs),...max.map(Math.abs)),margin=scale*2**-18;
 if(vertices.some(v=>Math.abs(v.reduce((n,value,i)=>n+value*normal[i],constant))>margin*length))return null;
 return{min:min.map(v=>v-margin),max:max.map(v=>v+margin)};
}
export function cameraSegmentOverlaps(bounds,from,to){
 if(!bounds||![...from,...to].every(Number.isFinite))return true;
 for(let i=0;i<3;i++)if(Math.max(from[i],to[i])<bounds.min[i]||Math.min(from[i],to[i])>bounds.max[i])return false;
 return true;
}

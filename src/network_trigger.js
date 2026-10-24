import {ShapeUtils,Vector2} from 'three';

export function networkTransitionTrigger(object){return object?.objectType===7&&!object.replicationRemoved&&Boolean(object.replicated?.hasTransition)&&!object.replicated?.isTrap;}
// Native client1407b1670 receives world-space vertices and raises Z by0.05;
//14086f940 derives the object's center from those vertices, not a separate U.
export function networkTriggerSurface(object){
 if(!networkTransitionTrigger(object))return null;
 const vertices=object.replicated?.vertices;
 if(!Array.isArray(vertices)||vertices.length<3||vertices.length>255||vertices.some(v=>!Array.isArray(v)||v.length!==3||!v.every(Number.isFinite)))return null;
 const points=vertices.map(v=>v.slice());if(points.length>3&&points[0].every((v,i)=>v===points.at(-1)[i]))points.pop();
 const triangles=ShapeUtils.triangulateShape(points.map(v=>new Vector2(v[0],v[1])),[]);if(!triangles.length)return null;
 const min=[0,1,2].map(i=>Math.min(...points.map(v=>v[i]))),max=[0,1,2].map(i=>Math.max(...points.map(v=>v[i]))),center=min.map((v,i)=>(v+max[i])/2);
 // A triangle centroid is inside even a concave transition polygon. It is
 // only an approach point; activation and server transfers remain remote.
 let best=null,area=-1;for(const t of triangles){const [a,b,c]=t.map(i=>points[i]),size=Math.abs((b[0]-a[0])*(c[1]-a[1])-(c[0]-a[0])*(b[1]-a[1]));if(size>area){area=size;best=[0,1,2].map(i=>(a[i]+b[i]+c[i])/3);}}
 if(!(area>0))return null;
 return{vertices:points.map(v=>[v[0],v[2]+.05,-v[1]]),triangles,center:[center[0],center[2]+.05,-center[1]],destination:best};
}

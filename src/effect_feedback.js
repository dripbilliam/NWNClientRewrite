const f=Math.fround;
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native effect floating feedback provider ${n} is unavailable`);return p[n](...args);};
// BroadcastFloatyEffect140439ae0. Projectile range268 is the radius with
// no+2/+45 expansion. Sorted upper-X exit and exact3D FLOAT squared distance.
// The message1404d95a0 writes target object32 then STRREF32 (type5/subtype5).
export async function broadcastEffectFloaty(actor,strref,p){
  const area=call(p,'area',actor);if(!area)return;
  const position=call(p,'position',actor).map(f),radius=f(actor.nativeProjectileRange268),low=f(position[0]-radius),high=f(position[0]+radius);
  if(!Number.isFinite(radius))throw new Error('Native effect floating feedback range268 is unavailable');
  const first=call(p,'firstByX',area,low);if(first===null)return;
  for(let index=first;;index++){
    const ids=call(p,'areaIds',area);if(index>=ids.length)return;
    const viewer=call(p,'object',ids[index]);if(!viewer||viewer.objectType<=4)continue;
    const point=call(p,'position',viewer).map(f);if(point[0]>high)return;
    const client=call(p,'client',viewer.id);if(!client)continue;
    const d=point.map((n,i)=>f(n-position[i])),squared=f(f(f(d[0]*d[0])+f(d[1]*d[1]))+f(d[2]*d[2]));
    if(squared<=f(radius*radius))await call(p,'send',client,{objectId:actor.id>>>0,strref:strref>>>0});
  }
}

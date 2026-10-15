import {OBJECT_INVALID} from './game_object_array.js';
const f=Math.fround;
const required=(p,n)=>{if(typeof p?.[n]!=='function')throw new Error(`Native player visibility count provider ${n} is unavailable`);return p[n];};
// GetFirst/GetNextObjectInArea14035e7f0/14035ea40 share area cursor238
// over the X-sorted228 list. CountVisibleToPlayers14036b870 deliberately
// looks up the client by AREA.ID (CGameObject138+8), not the current creature.
// Its input Vector.Z is raised again for each nearby admitted actor.
export async function countVisibleToPlayers(area,point,limit,p){
  if(!Number.isInteger(limit)||!Array.isArray(point)||point.length!==3||!point.every(Number.isFinite))throw new Error('Native player visibility count inputs are unavailable');
  limit|=0;area.nativeObjectCursor238=0;let count=0;
  while(area.nativeObjectCursor238<required(p,'spatialIds')(area).length&&count<limit){
    const id=p.spatialIds(area)[area.nativeObjectCursor238],o=required(p,'object')(id),actor=o?.objectType===5?o:null;
    if(actor&&required(p,'client')(area.id)){
      const at=required(p,'position')(actor),dx=f(f(point[0])-f(at[0])),dy=f(f(point[1])-f(at[1])),dz=f(f(point[2])-f(at[2]));
      const distance=f(f(f(dy*dy)+f(dx*dx))+f(dz*dz));
      if(distance<=900){point[2]=f(f(point[2])+1);const target=[f(at[0]),f(at[1]),f(f(at[2])+1)];
        if(await required(p,'lineOfSight')(area,point.slice(),target,[0,0,0],{id:OBJECT_INVALID},OBJECT_INVALID,OBJECT_INVALID,0)===1)count++;
      }
    }
    area.nativeObjectCursor238++;
  }
  return count;
}

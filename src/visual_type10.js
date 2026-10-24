import {nativeLogfBranches} from './native_log.js';
import {objectTemplateResRef} from './create_object.js';
const f=Math.fround,copy=v=>v.map(f),magnitude=v=>{const n=f(f(f(v[0]*v[0])+f(v[1]*v[1]))+f(v[2]*v[2]));return n>0?f(Math.sqrt(n)):0;};
const cvttLow=v=>Number.isFinite(v)&&v>=-(2**63)&&v<2**63?Math.trunc(v)>>>0:0;
const delta=(a,b)=>a.map((v,i)=>f(f(v)-f(b[i])));
//96a9a0 uses source/target ORIGINS for log, but launch/target for linear.
// This is client visual timing only; no spell damage or server RNG is resolved.
export function type10ProjectileTime(mode,from,to,launch,{logBranches=nativeLogfBranches}={}){
 mode=String(mode).split('\0')[0];
 if(mode==='log'){
  const distance=magnitude(delta(to,from)),times=logBranches(distance).map(log=>cvttLow(f(f(distance/f(f(log*3)+2))*1000)));
  if(!times.length||times.some(v=>v!==times[0]))throw new Error('Native procedural projectile CPU branches produce different travel times');return times[0];
 }
 const time=cvttLow(f(f(magnitude(delta(to,launch))/55)*1000));return mode==='linear2'?(time+time)>>>0:time;
}
// Whole native Type10 start96a9a0. Table, model and projectile services are
// explicit. The created projectile has independent lifetime from this visual.
export function startType10Visual(e,id,p){
 const target=p.clientObject(e.target54),targetRender=target?p.renderObject(target):null;
 const source=p.clientObject(e.source58),sourceRender=source?p.renderObject(source):null;
 if(!targetRender||!sourceRender)return null;
 id&=65535;
 const model=String(p.programString(id,'param1').value),spell=p.programInt(id,'param2'),facing=p.programInt(id,'param3'),path=p.programInt(id,'param4'),mode=String(p.programString(id,'param5').value);
 const projectile=p.constructProjectile();p.configureSpell(projectile,spell.found?spell.value|0:340);projectile.facing=(facing.found?facing.value:0)&255;
 if(!p.loadProjectileModel(projectile,objectTemplateResRef(model),255,0)){p.destroyProjectile(projectile);return projectile;}
 const position=[0,0,0],quaternion=[1,0,0,0];
 if(!p.sourceModel(sourceRender)||!p.sourceNodePose(p.sourceModel(sourceRender),'handconjure',position,quaternion))position.splice(0,3,...copy(sourceRender.position));
 p.projectilePosition(projectile,copy(position));p.projectileOrientation(projectile,copy(sourceRender.orientation));
 const client=p.controlledClient();if(client?.videoF8)p.projectileScene(projectile,client.videoF8.gui248);
 p.projectileStage(projectile,1);
 if(e.point48.every(v=>v===0)){projectile.endpoint=copy(targetRender.position);p.projectileTarget(projectile,targetRender.id,'');}
 else projectile.endpoint=copy(e.point48);
 const time=type10ProjectileTime(mode,sourceRender.position,targetRender.position,position,p);
 p.projectileTime(projectile,time);p.projectilePath(projectile,path.found?path.value|0:0);return projectile;
}

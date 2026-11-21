import {Vector3,Quaternion} from 'three';
// Camera path belongs to the replay; apply after the gameplay camera and before
// keyhole/light/frustum work. Interpolate orientation along the shortest arc.
export class SceneReplayCamera {
 constructor(samples){
  if(!Array.isArray(samples)||!samples.length)throw Error('Replay requires recorded camera samples');
  this.samples=samples;this.index=0;this.last=-1;this.a=new Quaternion();this.b=new Quaternion();this.position=new Vector3();
  for(let i=0;i<samples.length;i++)if(!Number.isFinite(samples[i].at)||samples[i].at<0||(i&&samples[i].at<samples[i-1].at))throw Error('Invalid replay camera timeline');
 }
 apply(at,areaId,camera,controls){
  if(!Number.isFinite(at)||at<this.last)throw Error('Replay camera clock moved backwards');this.last=at;
  while(this.index<this.samples.length-1&&this.samples[this.index+1].at<=at)this.index++;
  const a=this.samples[this.index],b=this.samples[Math.min(this.index+1,this.samples.length-1)];if(a.view.areaId!==areaId)return false;
  const t=b.view.areaId===areaId&&b.at>a.at?Math.max(0,Math.min(1,(at-a.at)/(b.at-a.at))):0;
  camera.position.fromArray(a.view.position).lerp(this.position.fromArray(b.view.position),t);
  camera.quaternion.copy(this.a.fromArray(a.view.quaternion).slerp(this.b.fromArray(b.view.quaternion),t));
  controls.target.fromArray(a.view.target).lerp(this.position.fromArray(b.view.target),t);
  for(const key of ['fov','near','far'])camera[key]=a.view[key]+(b.view[key]-a.view[key])*t;
  camera.updateProjectionMatrix();camera.updateMatrixWorld(true);return true;
 }
}

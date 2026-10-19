// Native48/1 timing is presentation only. Reaching100% never readies slots,
// heals, clears an action, or tells the server that resting completed.
export class NetworkTimingView{
 constructor(viewport,resolve){this.resolve=resolve;this.host=document.createElement('section');this.host.className='network-timing';this.host.hidden=true;this.host.setAttribute('role','status');this.label=document.createElement('span');this.bar=document.createElement('progress');this.host.append(this.label,this.bar);viewport.append(this.host);this.version=0;}
 reset(){this.version++;cancelAnimationFrame(this.frame);this.host.hidden=true;this.host.dataset.state=JSON.stringify({active:false});}
 async receive(message){this.reset();if(!message.active)return;const version=this.version,refs={1:0x10566,2:0x10567,3:0x10569,4:0x1056b,5:0x1056c,6:0x1056d,7:0x1056e,8:0x10570};this.label.textContent=refs[message.type]?await this.resolve({strRef:refs[message.type]}):'Action in progress';if(version!==this.version)return;this.host.hidden=false;this.bar.max=Math.max(1,message.duration);const start=performance.now();const tick=()=>{if(version!==this.version)return;this.bar.value=Math.min(this.bar.max,performance.now()-start);this.host.dataset.state=JSON.stringify({active:true,type:message.type,duration:message.duration,elapsed:this.bar.value});this.frame=requestAnimationFrame(tick);};tick();}
}

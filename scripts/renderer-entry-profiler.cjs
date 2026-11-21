// Sampling profiler for our replacement renderer only. No heap/values/network
// capture and no attachment to an original-game process.
const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
module.exports=async(window,output,report,at)=>{
 const debuggerApi=window.webContents.debugger;debuggerApi.attach('1.3');await debuggerApi.sendCommand('Profiler.enable');await debuggerApi.sendCommand('Profiler.setSamplingInterval',{interval:1000});let phase=null;
 return{
  async start(name){if(phase)throw Error('Entry profile already active');if(!['initial','transition'].includes(name))throw Error('Invalid profile phase');phase={name,start:at()};await debuggerApi.sendCommand('Profiler.start');},
  async stop(){if(!phase)return;const current=phase;phase=null;const {profile}=await debuggerApi.sendCommand('Profiler.stop');
   for(const node of profile.nodes){const url=node.callFrame.url;if(url?.startsWith('data:')||url?.length>1024)node.callFrame.url='<omitted non-file URL>';}
   const bytes=JSON.stringify(profile),filename=path.basename(output,'.json')+'-'+current.name+'.cpuprofile';await fs.writeFile(path.join(path.dirname(output),filename),bytes+'\n');(report.profiles??=[]).push({...current,end:at(),file:filename,samplingIntervalUs:1000,sha256:crypto.createHash('sha256').update(bytes+'\n').digest('hex'),samples:profile.samples?.length??0});
  },
  async dispose(){if(phase)await this.stop();if(debuggerApi.isAttached()){await debuggerApi.sendCommand('Profiler.disable');debuggerApi.detach();}}
 };
};

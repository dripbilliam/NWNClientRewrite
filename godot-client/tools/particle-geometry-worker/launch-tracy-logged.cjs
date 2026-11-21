'use strict';
// Private diagnostic launcher. Keep startup stderr when the Electron broker
// exits before the native engine is spawned.
const fs=require('node:fs'),path=require('node:path'),{spawn}=require('node:child_process');
const {verify}=require('../native-tracy/live/current-session.cjs');
const config=verify(path.resolve(process.argv[2]??''));
const launchFile=path.join(config.out,'launch.json');
if(fs.existsSync(launchFile))throw Error('Fresh session launch required');
const logFile=path.join(config.out,'launch.log'),fd=fs.openSync(logFile,'wx');
const env={...process.env};
for(const key of Object.keys(env))if(/^NWN_/i.test(key)||['ELECTRON_RUN_AS_NODE','NODE_OPTIONS'].includes(key))delete env[key];
env.NWN_PARTICLE_KERNEL='compiled';env.NWN_PARTICLE_BACKEND='native';
env.NWN_PRIVATE_TRACY_CONFIG=path.resolve(process.argv[2]);
env.NODE_OPTIONS='--require="'+path.join(config.source,'bootstrap-preload.cjs').replace(/\\/g,'/')+'"';
const args=['--disable-gpu',...config.bootstrapArguments,'--native-screen=1'];
const child=spawn(config.electron,args,{cwd:path.dirname(config.project),env,windowsHide:false,detached:true,stdio:['ignore',fd,fd]});
fs.closeSync(fd);child.unref();
fs.writeFileSync(launchFile,JSON.stringify({version:1,pid:child.pid,run:config.run,diagnosticOnly:true,screen:1,logged:true,automaticLogin:false})+'\n');
console.log(JSON.stringify({pid:child.pid,logFile}));

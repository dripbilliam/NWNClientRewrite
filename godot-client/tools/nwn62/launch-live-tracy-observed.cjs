'use strict';
// Diagnostic foreground launcher for a private Tracy session. Preserves the
// existing protected-settings preload and reports process exit without logging
// settings or authentication data to the console.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {spawn}=require('node:child_process');
const file=path.resolve(process.argv[2]??'');assert(file&&fs.existsSync(file),'Pinned config required');
const c=JSON.parse(fs.readFileSync(file));
require('../native-tracy/live/current-session.cjs').verify(file);
const output=path.join(c.out,'launcher-observed.log');assert(!fs.existsSync(output),'Preserve earlier diagnostics');
const log=fs.createWriteStream(output,{flags:'wx'});
const env={...process.env};
for(const key of Object.keys(env))if(key.toUpperCase().startsWith('NWN_')||['ELECTRON_RUN_AS_NODE','NODE_OPTIONS'].includes(key.toUpperCase()))delete env[key];
Object.assign(env,{NWN_PARTICLE_KERNEL:'compiled',NWN_PARTICLE_BACKEND:'native',NWN_PRIVATE_TRACY_CONFIG:file,NODE_OPTIONS:'--require="'+path.join(c.source,'bootstrap-preload.cjs').replace(/\\/g,'/')+'"'});
if(process.argv.includes('--disable-electron-gpu'))env.NWN_TRACY_ELECTRON_GPU_OFF='1';
const args=c.bootstrapArguments;
const child=spawn(c.electron,args,{cwd:path.dirname(c.project),env,windowsHide:false,stdio:['ignore','pipe','pipe']});
console.log(JSON.stringify({started:true,pid:child.pid,run:c.run,log:output}));
for(const stream of [child.stdout,child.stderr])stream.on('data',bytes=>log.write(bytes));
child.once('error',error=>{console.error(JSON.stringify({spawnError:error.message}));process.exitCode=1;});
child.once('exit',(code,signal)=>{log.end();console.log(JSON.stringify({exited:true,code,signal,run:c.run,log:output}));process.exitCode=code||0;});

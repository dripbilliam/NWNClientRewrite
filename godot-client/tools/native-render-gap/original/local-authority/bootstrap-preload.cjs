'use strict';
// NODE_OPTIONS is process-local and applies to launcher metadata Node tools too.
// They do nothing here; only Electron's exact ordinary bootstrap is wrapped.
if(process.type==='browser'&&process.env.NWN_NORMAL_FRONTEND_CONFIG){
 const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),childProcess=require('node:child_process');
 const config=JSON.parse(fs.readFileSync(process.env.NWN_NORMAL_FRONTEND_CONFIG));
 // Electron NODE_OPTIONS executes during browser_init. Wait for the exact
 // application's CJS entry rather than assuming argv already identifies it.
 const Module=require('node:module'),load=Module._load;
 function install(){
 const {app}=require('electron');assert(app,'Electron app API must be initialized at exact entry');
 if(config.bootstrapSha256)assert.equal(crypto.createHash('sha256').update(fs.readFileSync(config.bootstrap)).digest('hex'),config.bootstrapSha256);
 app.setName('nwn-model-viewer-research');const original=app.getPath('userData');
 const sha=b=>crypto.createHash('sha256').update(b).digest('hex'),copies=[];
 fs.mkdirSync(config.userdata,{recursive:true});function copy(file,target){if(fs.existsSync(file)){fs.copyFileSync(file,target,fs.constants.COPYFILE_EXCL);copies.push({source:file,destination:target,sha256:sha(fs.readFileSync(file))});}}
 // Chromium wraps the Windows DPAPI key in this profile's Local State. Copy
 // its protected context together with the encrypted settings before Electron
 // initializes OSCrypt; no encrypted or plaintext values enter our reports.
 for(const name of['Local State','client-settings.json','native-server-browser.json'])copy(path.join(original,name),path.join(config.userdata,name));
 const godotUser=path.join(app.getPath('appData'),'Godot/app_userdata/NWN Native Engine Prototype');
 for(const[from,to]of[['native-options.cfg','native-render-preferences.cfg'],['native-menu-layout.cfg','native-menu-layout.cfg'],['native-character-lobby.cfg','native-lobby-preferences.cfg']])copy(path.join(godotUser,from),path.join(config.userdata,to));
 fs.writeFileSync(path.join(config.out,'settings-copies.json'),JSON.stringify({version:1,copies,scope:'Protected settings and native preference working copies only. Source content is never logged or written.'},null,2)+'\n',{flag:'wx'});
 app.setPath('userData',config.userdata);app.setPath('sessionData',config.userdata);app.setPath('logs',config.userdata);app.setPath('crashDumps',config.userdata);
 const spawn=childProcess.spawn;childProcess.spawn=function(file,args,options){if(file==='node'&&path.resolve(args[0])===config.host){const env={...process.env,...options?.env,NWN_NORMAL_FRONTEND_CONFIG:process.env.NWN_NORMAL_FRONTEND_CONFIG};delete env.NODE_OPTIONS;const child=Reflect.apply(spawn,this,[file,['--require',path.join(__dirname,'host-preload.cjs'),...args],{...options,env}]);const end=child.stdin.end;child.stdin.end=function(bytes,callback){const value=JSON.parse(bytes);value.userDirectory=config.userdir;value.settingsDirectory=config.userdata;const copied=Buffer.from(JSON.stringify(value));return Reflect.apply(end,this,[copied,()=>{copied.fill(0);callback?.();}]);};return child;}return Reflect.apply(spawn,this,[file,args,options]);};
 }
 Module._load=function(request,...rest){if(typeof request==='string'&&path.isAbsolute(request)&&path.resolve(request)===config.bootstrap){Module._load=load;try{install();}catch(error){process.stderr.write('Owned frontend preload failed: '+error.stack+'\n');process.exit(1);}}return Reflect.apply(load,this,[request,...rest]);};
}

'use strict';
// Same ordinary protected-settings broker; process-local working-copy wrapper.
if(process.type==='browser'&&process.env.NWN_PRIVATE_LIVE_CONFIG){
 const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),Module=require('node:module'),childProcess=require('node:child_process'),assert=require('node:assert/strict');
 const config=JSON.parse(fs.readFileSync(process.env.NWN_PRIVATE_LIVE_CONFIG)),load=Module._load,sha=b=>crypto.createHash('sha256').update(b).digest('hex');
 function install(){
  assert.equal(sha(fs.readFileSync(config.bootstrap)),config.bootstrapSha256);const {app}=require('electron');app.setName('nwn-model-viewer-research');const original=app.getPath('userData'),copies=[];
  fs.mkdirSync(config.userdata,{recursive:true});function copy(file,target){if(fs.existsSync(file)){fs.copyFileSync(file,target,fs.constants.COPYFILE_EXCL);copies.push({source:file,destination:target,sha256:sha(fs.readFileSync(file)),bytes:fs.statSync(file).size});}}
  for(const name of ['Local State','client-settings.json','native-server-browser.json'])copy(path.join(original,name),path.join(config.userdata,name));
  const godotUser=path.join(app.getPath('appData'),'Godot/app_userdata/NWN Native Engine Prototype');
  for(const [from,to]of [['native-options.cfg','native-render-preferences.cfg'],['native-menu-layout.cfg','native-menu-layout.cfg'],['native-character-lobby.cfg','native-lobby-preferences.cfg']])copy(path.join(godotUser,from),path.join(config.userdata,to));
  fs.writeFileSync(path.join(config.out,'working-settings-proof.json'),JSON.stringify({version:1,copies,scope:'Encrypted settings/context and native preferences copied only; contents never logged. Documents/NWSync source remains the ordinary user-selected profile.'},null,2)+'\n',{flag:'wx'});
  app.setPath('userData',config.userdata);app.setPath('sessionData',config.userdata);app.setPath('logs',config.userdata);app.setPath('crashDumps',config.userdata);
  const spawn=childProcess.spawn;childProcess.spawn=function(file,args,options){if(file==='node'&&Array.isArray(args)&&path.resolve(args[0])===config.host){const env={...process.env,...options?.env,NWN_PRIVATE_LIVE_CONFIG:process.env.NWN_PRIVATE_LIVE_CONFIG,NWN_PRIVATE_TRANSPORT_CONTROL:config.controlFile};delete env.NODE_OPTIONS;return Reflect.apply(spawn,this,[file,['--require',path.join(__dirname,'host-preload.cjs'),...args],{...options,env}]);}return Reflect.apply(spawn,this,[file,args,options]);};
 }
 Module._load=function(request,...rest){if(typeof request==='string'&&path.isAbsolute(request)&&path.resolve(request)===config.bootstrap){Module._load=load;install();}return Reflect.apply(load,this,[request,...rest]);};
}

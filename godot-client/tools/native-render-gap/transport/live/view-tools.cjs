'use strict';
const path=require('node:path');
function replaceOne(source,before,after){if(source.split(before).length!==2)throw Error('Private live source seam changed');return source.replace(before,after);}
function liveHostSource(source,{view,helper}){let text=replaceOne(source,"require('./native-render-gap/transport/host-window.cjs')",'require('+JSON.stringify(helper)+')');text=replaceOne(text,".HostWindow)({project,enabled:",'.HostWindow)({project:'+JSON.stringify(view)+',enabled:');return text;}
function nativeArguments(args,config){
 const copy=[...args],at=copy.indexOf('--path');if(at<0||copy[at+1]!==config.project)throw Error('Normal native project path differs');copy[at+1]=config.view;
 if(copy.some(x=>typeof x==='string'&&/^--(?:offline-replay|recording|record-loading|particle-key-survey|particle-core-survey)/.test(x)))throw Error('Live source view cannot combine replay/recording/probes');
 copy.push('--render-preferences='+path.join(config.userdata,'native-render-preferences.cfg'),'--menu-layout='+path.join(config.userdata,'native-menu-layout.cfg'),'--lobby-preferences='+path.join(config.userdata,'native-lobby-preferences.cfg'));
 return copy;
}
module.exports={liveHostSource,nativeArguments};

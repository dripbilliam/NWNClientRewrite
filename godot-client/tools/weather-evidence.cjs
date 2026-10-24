const {integrationComplete}=require('./integration-evidence.cjs');
function weatherIntegrationComplete(report){
 const test=report.weatherTest;
 if(!integrationComplete('text',report)||!test?.completed||!test.presentationPending||test.phases?.length!==5||test.checks?.length<18||!test.checks.every(v=>v.passed))return false;
 const expected=[[1,true],[2,true],[0,true],[1,true],[0,true]];
 if(!(report.weatherDelivered?.length>=6&&report.weatherObserved?.length>=6))return false;
 if(new Set(test.phases.map(v=>v.revision)).size!==5||(report.weatherWire?.length??0)<5)return false;
 return expected.every(([type,enabled],i)=>{
  const phase=test.phases[i],delivery=report.weatherDelivered.find(v=>v.revision===phase.revision),observed=report.weatherObserved.find(v=>v.revision===phase.revision);
  const active=enabled&&type!==0;
  const wire=report.weatherWire[i],scope=['connection','areaId','generation','transferId'];
  return phase.type===type&&phase.enabled===enabled&&phase.acknowledged&&phase.state.current===(active?type:0)&&phase.state.target===(enabled?type:0)&&phase.state.intensity===(active?100:0)&&phase.state.plannedInstances===(active?6:0)&&phase.state.remainingMs===0&&phase.state.presentationPending===true&&delivery?.weather.type===type&&delivery?.weather.enabled===enabled&&observed?.applied===true&&scope.every(k=>delivery[k]===observed[k]&&delivery[k]===report.nativeLoaded[0][k])&&wire?.connection===delivery.connection&&wire.weather.type===type&&Boolean(wire.weather.enabled)===enabled;
 });
}
function weatherRenderIntegrationComplete(report){
 const t=report.weatherTest;if(!weatherIntegrationComplete(report)||!t.renderingRequired||t.renderSamples?.length!==3||t.transitions?.length!==2||report.nativeLoaded.length!==3||report.rejectedCommands?.length)return false;
 if(!t.renderSamples.every(v=>v.changedPixels>=16&&v.vertices>0&&v.emitters===24&&v.saved&&v.models.models===6&&v.models.particleReady&&v.models.stats.failures===0))return false;
 if(t.firstRenderer?.models!==0||t.firstRenderer.stats.created!==18||t.firstRenderer.stats.removed!==18||t.firstRenderer.stats.failures!==0)return false;
 return t.transitions.every((v,i)=>v.ready&&!v.oldWeatherAlive&&v.oldModelsAlive===0&&v.renderer.models===6&&v.renderer.current===(i===0?2:1)&&v.renderer.stats.failures===0&&v.areaId===report.nativeLoaded[i+1].areaId&&v.generation===report.nativeLoaded[i+1].generation)&&t.renderer.models===6&&t.renderer.current===1;
}
module.exports={weatherIntegrationComplete,weatherRenderIntegrationComplete};

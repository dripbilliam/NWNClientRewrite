// Launch configuration only. Rendering and resource preparation remain native.
// Keep the room-validated lighting and particle options together so a normal
// launch cannot accidentally revert to the older dark material/output path.
const profiles=Object.freeze({
 gameplay:Object.freeze({lighting:'enhanced',history:'1',surface:'true',presentation:'shared',particleLighting:'pooled'}),
 legacy:Object.freeze({lighting:'godot',history:'0',surface:'false',presentation:'individual',particleLighting:'scene'})
});
function resolveNativeRenderConfiguration({arg=()=>undefined,env={},isolated=false}={}){
 const explicit=arg('render-profile');
 if(explicit!==undefined&&!Object.hasOwn(profiles,explicit))throw Error('Invalid native render profile');
 // Preserve explicit historical research commands. An individual lighting flag
 // without a named profile starts from the old baseline, then records "custom".
 const lightingOverrides=['native-lighting','native-light-history','native-surface-output'].some(name=>arg(name)!==undefined)||['NWN_NATIVE_LIGHTING','NWN_NATIVE_LIGHT_HISTORY','NWN_NATIVE_SURFACE_OUTPUT'].some(name=>env[name]!==undefined);
 const profile=explicit??(isolated||lightingOverrides?'legacy':'gameplay');
 const defaults=profiles[profile];
 // An explicitly named complete profile wins over inherited research switches.
 // Individual command-line overrides are still deliberate and remain supported.
 const inherited=explicit===undefined?env:{};
 const lighting=arg('native-lighting')??inherited.NWN_NATIVE_LIGHTING??defaults.lighting;
 const history=arg('native-light-history')??inherited.NWN_NATIVE_LIGHT_HISTORY??defaults.history;
 const surface=arg('native-surface-output')??inherited.NWN_NATIVE_SURFACE_OUTPUT??defaults.surface;
 if(!['godot','enhanced'].includes(lighting))throw Error('Invalid native lighting mode');
 if(!['0','1'].includes(history))throw Error('Invalid native light history switch');
 if(!['true','false'].includes(surface))throw Error('Invalid native surface-output switch');
 if(history==='1'&&lighting!=='enhanced')throw Error('Native light history requires enhanced lighting');
 if(surface==='true'&&(lighting!=='enhanced'||history!=='1'))throw Error('Native surface output requires enhanced lighting and native light history');
 const presentation=arg('particle-presentation')??inherited.NWN_PARTICLE_PRESENTATION??defaults.presentation;
 const particleLighting=arg('particle-lighting')??inherited.NWN_PARTICLE_LIGHTING??defaults.particleLighting;
 if(!['individual','shared'].includes(presentation))throw Error('Invalid native particle presentation');
 if(!['scene','pooled'].includes(particleLighting))throw Error('Invalid native particle lighting');
 const args=[];
 let maximumLights;
 const requestedShadows=arg('native-shadow-lights')??inherited.NWN_NATIVE_SHADOW_LIGHTS;
 const shadowLights=Number(requestedShadows??1);
 if(String(requestedShadows??1).trim()===''||!Number.isInteger(shadowLights)||shadowLights<0||shadowLights>4)throw Error('Invalid native point-shadow limit');
 if(requestedShadows!==undefined)args.push('--native-shadow-lights='+shadowLights);
 const postprocess={mask:16,midpoint:.4,intensity:0,vibrance:0};
 if(lighting==='enhanced')args.push('--native-lighting=enhanced');
 const requestedMaximum=arg('native-max-lights')??inherited.NWN_NATIVE_MAX_LIGHTS;
 if(requestedMaximum!==undefined&&history!=='1')throw Error('Native maximum lights requires native light history');
 if(history==='1'){
  maximumLights=Number(requestedMaximum??32);
  if(String(requestedMaximum??32).trim()===''||!Number.isInteger(maximumLights)||maximumLights<0||maximumLights>128)throw Error('Invalid native maximum lights');
  args.push('--native-light-history','--native-max-lights='+maximumLights);
 }
 if(surface==='true'){
  args.push('--native-surface-output=true');
  // Match the original client's enabled high-contrast/vibrance stages. Gamma
  // alone can fix brightness while leaving this room's colors visibly flat.
  const tonalDefaults=profile==='gameplay'?{mask:'28',midpoint:'.4',intensity:'.15',vibrance:'.7'}:{};
  for(const field of ['mask','midpoint','intensity','vibrance']){
   const value=arg('native-postprocess-'+field)??env['NWN_NATIVE_POSTPROCESS_'+field.toUpperCase()]??tonalDefaults[field];
   if(value!==undefined){
    const numeric=Number(value);
    if(String(value).trim()===''||!Number.isFinite(numeric)||!Number.isFinite(Math.fround(numeric))||(field==='mask'&&(!Number.isInteger(numeric)||numeric<0||numeric>28||(numeric&~28)!==0)))throw Error('Invalid native postprocess '+field);
    args.push('--native-postprocess-'+field+'='+numeric);postprocess[field]=numeric;
   }
  }
 }
 const gamma=arg('native-gamma')??env.NWN_NATIVE_GAMMA;
 let gammaValue;
 if(gamma!==undefined){
  gammaValue=Number(gamma);
  if(String(gamma).trim()===''||!Number.isFinite(gammaValue)||gammaValue<0||gammaValue>1000)throw Error('Invalid native gamma setting');
  args.push('--native-gamma='+gammaValue);
 }
 const selected={lighting,history,surface,presentation,particleLighting};
 let effective=Object.keys(profiles).find(name=>Object.entries(profiles[name]).every(([key,value])=>selected[key]===value))??'custom';
 if(effective==='gameplay'&&(maximumLights!==32||postprocess.mask!==28||postprocess.midpoint!==.4||postprocess.intensity!==.15||postprocess.vibrance!==.7))effective='custom';
 if(shadowLights!==1)effective='custom';
 return {
  arguments:args,
  environment:{NWN_PARTICLE_PRESENTATION:presentation,NWN_PARTICLE_LIGHTING:particleLighting},
  summary:{profile:effective,base_profile:profile,selection:explicit!==undefined?'explicit':lightingOverrides?'lighting overrides':isolated?'isolated check':'normal gameplay',engine:'godot-forward-plus',lighting,light_history:history==='1',...(maximumLights!==undefined?{maximum_lights:maximumLights}:{}),point_shadow_lights:shadowLights,shadow_selection:'player-focus original ranking/support within a scene-wide Godot map budget; original per-pass/stencil/fades pending',surface_output:surface==='true',particle_presentation:presentation,particle_lighting:particleLighting,postprocess,...(gammaValue!==undefined?{gamma:gammaValue}:{})}
 };
}
module.exports={resolveNativeRenderConfiguration};

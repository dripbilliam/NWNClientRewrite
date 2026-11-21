param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Variant,
    [Parameter(Mandatory=$true)][ValidatePattern('^native-perf140-[a-z0-9-]+$')][string]$Run,
    [switch]$Detailed,
    [switch]$TcpNoDelay,
    [switch]$Debugger,
    [ValidateSet('default','safe','separate')][string]$RenderThread='default',
    [ValidateSet('forward_plus','mobile')][string]$RenderingMethod='forward_plus',
    [ValidateSet('debug','release','custom-pristine','custom-patched','custom-scene','custom-builtin')][string]$Engine='debug',
    [ValidatePattern('^(engine-(rd|scene|builtin|pushed)-[a-z0-9-]+|engine-synchronous-particle-reads-v2)$')][string]$CustomEngineDescriptor,
    [ValidatePattern('^release-pack-[a-z0-9-]+$')][string]$ReleasePackage,
    [ValidateSet('script','native')][string]$ParticleRandom='script',
    [ValidateSet('script','native')][string]$ParticleClocks='script',
    [ValidateSet('off','managed')][string]$ParticlePoseLeases='off',
    [ValidateSet('off','retained')][string]$ParticleCommon='off',
    [ValidateSet('off','eligibility','full')][string]$ParticleSceneSnapshot='off',
    [ValidateSet('off','enabled')][string]$StaticEmitterRoute='off',
    [ValidateSet('default','deferred')][string]$RasterCacheWrite='default',
    [ValidateSet('scalar','bulk')][string]$ModelFloatStream='scalar',
    [ValidateSet('extension','builtin')][string]$LightInputRegistry='extension',
    [ValidateSet('pull','published')][string]$LightInputFields='pull',
    [ValidateSet('off','managed')][string]$ParticleEligibility='off',
    [ValidateSet('ordinary','typed')][string]$ParticleInputs='ordinary',
    [ValidateSet('ordinary','indexed')][string]$ParticlePoseSlots='ordinary',
    [ValidateSet('ordinary','eligibility','full')][string]$ParticleEngineReads='ordinary',
    [ValidateSet('original','retained')][string]$GeneratedLightManual='original',
    [ValidateSet('legacy','indexed')][string]$DriveCollision='legacy',
    [ValidateSet('script','native')][string]$DriveClear='script',
    [ValidateSet('script','native')][string]$TerrainHeight='script',
    [switch]$ObserveProfile,
    [switch]$ReplayMovement,
    [string]$CacheDirectory,
    [ValidateRange(10000,60000)][int]$SteadyMs=30000
)
$ErrorActionPreference='Stop'
$project=Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$manifestFile=Join-Path $project ('.cache/native-140fps/root/'+$Variant+'/manifest.json')
$manifest=Get-Content -LiteralPath $manifestFile -Raw|ConvertFrom-Json
$preview=Get-Content -LiteralPath (Join-Path $project 'reports/native-movement-replay-preview-latest.json') -Raw|ConvertFrom-Json
if(@(Get-ChildItem -LiteralPath (Join-Path $project 'reports') -Filter ($Run+'.*') -File).Count){throw 'Existing benchmark artifacts are preserved; choose a fresh run name.'}
$env:NWN_PARTICLE_KERNEL='compiled'
$env:NWN_PARTICLE_PRESENTATION='shared'
$env:NWN_PARTICLE_LIGHTING='pooled'
$env:NWN_PARTICLE_RANDOM='script'
$env:NWN_PARTICLE_CLOCKS='script'
$env:NWN_PARTICLE_POSE_LEASES='off'
$env:NWN_PARTICLE_COMMON='off'
$env:NWN_PARTICLE_SCENE_SNAPSHOT='off'
$env:NWN_PARTICLE_ELIGIBILITY='off'
$env:NWN_PARTICLE_INPUTS='ordinary'
$env:NWN_PARTICLE_POSE_SLOTS='ordinary'
$env:NWN_PARTICLE_READS='ordinary'
$env:NWN_GENERATED_LIGHT_MANUAL='original'
. (Join-Path $project 'tools/native-window-screen.ps1')
$gpuScreen=Get-NativeSecondaryScreen
$gpuArgs=@(('--capture='+$preview.capture),('--source-project='+$manifest.project),('--run='+$Run),'--generation=2',('--steady-ms='+$SteadyMs),'--settle-ms=5000',('--profiling='+$Detailed.IsPresent.ToString().ToLowerInvariant()),'--native-lighting=enhanced','--native-light-history=1','--native-surface-output=true','--native-postprocess-mask=28','--native-postprocess-midpoint=0.4','--native-postprocess-intensity=0.15','--native-postprocess-vibrance=0.7')
if($gpuScreen-ge0){$gpuArgs+=('--screen='+$gpuScreen)}
if($TcpNoDelay){$gpuArgs+='--tcp-no-delay=true'}
if($Debugger){$gpuArgs+='--debugger'}
if($RenderThread-ne'default'){$gpuArgs+=('--render-thread='+$RenderThread)}
$gpuArgs+=('--rendering-method='+$RenderingMethod)
if($Engine-ne'debug'){$gpuArgs+=('--engine='+$Engine)}
if($CustomEngineDescriptor){$gpuArgs+=('--custom-engine-descriptor='+$CustomEngineDescriptor)}
if($ReleasePackage){$gpuArgs+=('--release-package='+$ReleasePackage)}
if($ParticleRandom-ne'script'){$gpuArgs+=('--particle-random='+$ParticleRandom)}
if($ParticleClocks-ne'script'){$gpuArgs+=('--particle-clocks='+$ParticleClocks)}
if($ParticlePoseLeases-ne'off'){$gpuArgs+=('--particle-pose-leases='+$ParticlePoseLeases)}
if($ParticleCommon-ne'off'){$gpuArgs+=('--particle-common='+$ParticleCommon)}
if($ParticleSceneSnapshot-ne'off'){$gpuArgs+=('--particle-scene-snapshot='+$ParticleSceneSnapshot)}
if($StaticEmitterRoute-ne'off'){$gpuArgs+=('--static-emitter-route='+$StaticEmitterRoute)}
if($RasterCacheWrite-ne'default'){$gpuArgs+=('--raster-cache-write='+$RasterCacheWrite)}
if($ModelFloatStream-ne'scalar'){$gpuArgs+=('--model-float-stream='+$ModelFloatStream)}
if($LightInputRegistry-ne'extension'){$gpuArgs+=('--light-input-registry='+$LightInputRegistry)}
if($LightInputFields-ne'pull'){$gpuArgs+=('--light-input-fields='+$LightInputFields)}
if($ParticleEligibility-ne'off'){$gpuArgs+=('--particle-eligibility='+$ParticleEligibility)}
if($ParticleInputs-ne'ordinary'){$gpuArgs+=('--particle-inputs='+$ParticleInputs)}
if($ParticlePoseSlots-ne'ordinary'){$gpuArgs+=('--particle-pose-slots='+$ParticlePoseSlots)}
if($ParticleEngineReads-ne'ordinary'){$gpuArgs+=('--particle-engine-reads='+$ParticleEngineReads)}
if($GeneratedLightManual-ne'original'){$gpuArgs+=('--generated-light-manual='+$GeneratedLightManual)}
$gpuArgs+=('--drive-collision='+$DriveCollision)
if($DriveClear-ne'script'){
    if($DriveCollision-ne'indexed'){throw 'Compiled drive clear requires the indexed collision owner.'}
    $gpuArgs+=('--drive-clear='+$DriveClear)
}
$gpuArgs+=('--terrain-height='+$TerrainHeight)
if($ObserveProfile){$gpuArgs+='--observe-profile=true'}
if($ReplayMovement){$gpuArgs+='--movement-timing'}
if($CacheDirectory){$gpuArgs+=('--cache-directory='+$CacheDirectory)}
& node (Join-Path $project 'tools/replay-native-loading.mjs') @gpuArgs
if($LASTEXITCODE-ne0){exit $LASTEXITCODE}

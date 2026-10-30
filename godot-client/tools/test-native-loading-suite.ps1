param(
 [Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]{3,55}$')][string]$RunPrefix,
 [Parameter(Mandatory)][string]$Catalog,
 [Parameter(Mandatory)][string]$NwsyncFixture,
 [Parameter(Mandatory)][string]$Baseline
)
$ErrorActionPreference='Stop'
$suiteProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$suiteOutput=Join-Path $suiteProject ('reports/'+$RunPrefix+'.suite.json')
if(Test-Path -LiteralPath $suiteOutput){throw 'Loading suite output already exists'}
foreach($suiteInput in @($Catalog,$NwsyncFixture,$Baseline)){if(-not(Test-Path -LiteralPath $suiteInput)){throw 'Explicit local suite fixture is unavailable'}}
$suiteCases=@(
 @('index','native_resource_index_test.gd',11,@()),
 @('coalescing','native_preparation_coalescing_test.gd',12,@()),
 @('publication','native_loading_publication_test.gd',12,@()),
 @('session-cache','native_session_render_cache_test.gd',18,@()),
 @('ordering','native_player_stream_order_test.gd',20,@()),
 @('adoption','native_loading_adoption_test.gd',6,@()),
 @('retirement','native_world_retirement_test.gd',78,@()),
 @('retirement-physics','native_retirement_physics_test.gd',10,@()),
 @('recording','native_loading_recording_test.gd',17,@()),
 @('source-bytes','native_source_bytes_cache_test.gd',15,@('--fixture='+$NwsyncFixture)),
 @('nwsync','native_nwsync_test.gd',38,@('--fixture='+$NwsyncFixture)),
 @('data-retirement','native_area_data_retirement_test.gd',12,@()),
 @('actor-retirement','native_entity_data_retirement_test.gd',10,@()),
 @('packed-keys','native_packed_animation_test.gd',67,@('--catalog='+$Catalog)),
 @('ascii','native_ascii_loading_test.gd',15,@("--catalog=$Catalog","--baseline=$Baseline")),
 @('ascii-typed','native_ascii_typed_keys_test.gd',81,@('--catalog='+$Catalog)),
 @('ui-data-retirement','native_ui_data_retirement_test.gd',20,@()),
 @('prepared-writer','native_prepared_write_queue_test.gd',27,@('--prepared-cache-write=deferred','--prepared-cache-lock=path')),
 @('cache-paths','native_cache_publication_paths_test.gd',13,@()),
 @('skin-stream','native_skin_preparation_test.gd',277,@('--catalog='+$Catalog),$true),
 @('skin-cache','native_skin_cache_test.gd',12,@()),
 @('clip-index','native_clip_index_test.gd',81,@('--catalog='+$Catalog)),
 @('pipeline-monitors','native_pipeline_monitors_test.gd',11,@()),
 @('summary-worker','native_frame_summary_worker_test.gd',52,@()),
 @('material-cold','native_material_prewarm_test.gd',12,@('--catalog='+$Catalog),$true),
 @('material-prewarm','native_material_prewarm_test.gd',12,@("--catalog=$Catalog",'--prewarm=true'),$true),
 @('tables','native_twoda_loading_test.gd',30,@("--catalog=$Catalog","--baseline=$Baseline")),
 @('table-cost','native_table_cache_cost_test.gd',23,@('--catalog='+$Catalog)),
 @('prepared-cache','native_prepared_cache_test.gd',16,@()),
 @('inheritance','native_actor_inheritance_loading_test.gd',16,@('--catalog='+$Catalog)),
 @('validation','native_animation_validation_test.gd',252,@()),
 @('persistent-actors','native_actor_persistent_loading_test.gd',14,@('--catalog='+$Catalog)),
 @('entry-prefetch','native_entry_prefetch_test.gd',9,@()),
 @('actor-failure','native_actor_visual_failure_test.gd',27,@()),
 @('static-failure','native_visual_failure_test.gd',28,@()),
 @('ancestors','native_ancestor_preparation_test.gd',42,@('--catalog='+$Catalog)),
 @('raster-pixels','native_raster_conversion_test.gd',608,@('--catalog='+$Catalog)),
 @('palette-preparation','native_palette_preparation_test.gd',25,@()),
 @('mesh-preparation','native_mesh_preparation_test.gd',846,@('--catalog='+$Catalog)),
 @('mesh-cache','native_mesh_cache_test.gd',14,@()),
 @('failed-model','native_failed_model_coalescing_test.gd',10,@()),
 @('postdraw','native_frame_postdraw_test.gd',8,@(),$true),
 @('icon-reuse','native_icon_model_reuse_test.gd',20,@('--catalog='+$Catalog),$true),
 @('vertices','native_particle_vertices_test.gd',1227,@('--kernel=compiled')),
 @('geometry','native_scene_geometry_kernel_test.gd',2137,@('--kernel=compiled'))
)
$suiteRows=@()
foreach($suiteCase in $suiteCases){
 $suiteRun=$RunPrefix+'-'+$suiteCase[0]+'-v1'
 $suiteArguments=@($suiteCase[3])
 $suiteGraphical=$suiteCase.Count-gt4-and[bool]$suiteCase[4]
 $suiteConsole=& (Join-Path $PSScriptRoot 'test-native-kernel-debugger.ps1') -Run $suiteRun -Script ('res://tests/'+$suiteCase[1]) -TestArguments $suiteArguments -Graphical:$suiteGraphical
 $suiteResult=Get-Content (Join-Path $suiteProject ('reports/'+$suiteRun+'.json')) -Raw|ConvertFrom-Json
 if(-not$suiteResult.success-or$suiteResult.checks-ne$suiteCase[2]){throw ('Loading suite assertion count/success differs: '+$suiteRun)}
 $suiteRows+=@{name=$suiteCase[0];run=$suiteRun;checks=$suiteResult.checks;success=$true}
 Write-Output ($suiteConsole|Select-Object -Last 1)
}
$suiteSummary=[ordered]@{success=$true;checks=($suiteRows|Measure-Object -Property checks -Sum).Sum;cases=$suiteRows;publicConnections=0;scope='Current-source CDB/native-heap focused loading and ABI tests; no original executable timing, GPU/FPS, full-world or complete gameplay acceptance'}
[IO.File]::WriteAllText($suiteOutput,($suiteSummary|ConvertTo-Json -Depth 5)+[Environment]::NewLine)
Write-Output (@{success=$true;checks=$suiteSummary.checks;report=$suiteOutput}|ConvertTo-Json -Compress)

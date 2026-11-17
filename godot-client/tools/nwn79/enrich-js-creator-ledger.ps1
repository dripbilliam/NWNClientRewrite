param([string]$LedgerPath = (Join-Path $PSScriptRoot 'js-runtime-function-ledger-v1.json'))
$ErrorActionPreference = 'Stop'
$ledger = Get-Content -LiteralPath $LedgerPath -Raw | ConvertFrom-Json -AsHashtable
$modules = @{}
foreach ($module in $ledger.moduleRecords) { $modules[$module.oldPath] = $module }

function Map-Group([string]$path, [string[]]$names, [string]$replacement, [string]$caller, [string]$gap, [string[]]$evidence = @()) {
    if (-not $modules.ContainsKey($path)) { throw "Missing module: $path" }
    $module = $modules[$path]
    foreach ($name in $names) {
        $matches = @($module.functions | Where-Object oldSymbol -eq $name)
        if ($matches.Count -eq 0) { throw "Missing function: ${path}::$name" }
        foreach ($row in $matches) {
            $row.status = 'partial'
            $row.godotReplacement = $replacement
            $row.actualGodotCaller = $caller
            $row.evidence = @($evidence)
            $row.gap = $gap
        }
    }
    $module.moduleDisposition = 'partial source map; whole file retained pending branch and live parity'
    $module.moduleComplete = $false
}

$creation = 'src/character_creation.js'
Map-Group $creation @('rows','cell','num','present','at','classTable','cfg') 'systems/native_data/creation_rules.gd::rows/row/cell/num/present/class_rows/cfg' 'NativeCreation uses CreationRules during source UI render/edit' 'Exact 2DA lookup/default and every consumer branch not yet parity tested'
Map-Group $creation @('loadCreationRules','load') 'NativeCreation.table/enqueue/prepared; CreationRules table state' 'NativeCreation loads rules before source editor steps' 'Old rule-load set/order and failures not yet parity tested'
Map-Group $creation @('creationAlignmentAllowed','ALIGNMENTS') 'CreationRules.alignment_allowed/alignment' 'NativeCreation source-step class/alignment controls' 'All race/class alignment combinations unverified'
Map-Group $creation @('abilityPointCost','initialCreationDraft','creationAbilities','initializeCreationAbilities','creationAbilityCanDecrease','creationPointBalance') 'CreationRules.point_cost/initialize/abilities/initialize_abilities/can_decrease/point_balance' 'NativeCreation source-step attributes controls' 'Only Fighter creation path has physical source-I evidence; other races/packages unverified'
Map-Group $creation @('creationPackageOptions','creationDefaultPackage','creationClassRequirement') 'CreationRules.packages/default_package/class_requirement/commit_class' 'NativeCreation source-step class/package controls' 'Package defaults/recommendation variants unverified'
Map-Group $creation @('creationSkillBudget','creationSkillRule','creationSkillBalance') 'CreationRules.skill_budget/skill_rule/skill_balance' 'NativeCreation source-step skill controls' 'Cross-class, race and level variants unverified'
Map-Group $creation @('creationGrantedFeats','creationFeatSlots','creationFeatListAllows','creationFeatRequirements') 'CreationRules.granted_feats/feat_slots/feat_allowed/feat_requirement' 'NativeCreation source-step feat controls; NativeLevelUp rules reuse separately' 'Feat prerequisite and class variants unverified'
Map-Group $creation @('creationSpellOptions','creationSpellCount','creationSpellSlots','creationPreparedOptions') 'CreationRules.spell_options/spell_count/spell_slots/prepared_options' 'NativeCreation source-step spell controls; NativeLevelUp rules reuse separately' 'Caster, domain, metamagic and associate variants unverified'
Map-Group $creation @('creationPortraits','creationVoices','creationPhenotypes','creationClothes','creationHeadModels') 'CreationRules.portraits/voices/phenotypes/clothes/heads' 'NativeCreation source appearance/voice controls' 'Asset availability and fallback variants unverified'
Map-Group $creation @('creationErrors') 'CreationRules.errors; CreationBic.validation_errors' 'NativeCreation calls rules.errors before begin_build' 'All invalid-draft and recovery branches unverified'
Map-Group $creation @('recommendAbilities','recommendCreation','preference') 'CreationRules.recommend_abilities/recommend/preference' 'NativeCreation recommendation controls' 'Per-class recommendation and disabled-button variants unverified'
Map-Group $creation @('list','createCharacterBic') 'CreationBic.list/build; CreationTailBic patch' 'NativeCreation.begin_build:811-827; DirectWorld submits native subtype19' 'Focused Fighter BIC and source-I server creation pass; remaining writer and local-vault variants unverified' @('godot-client/tests/nwn79_server_create_bic_test.gd','.cache/nwn79-vault-create-reconnect-source-20261116-i/amended-evidence.json')

$assets = 'src/character_creation_assets.js'
Map-Group $assets @('loadCharacterCreationAssets','load') 'NativeCreationPreview.refresh/refresh_source/queue_model/install_pending; NativeLiveWorld model/texture pipeline' 'NativeCreation.render:718 invokes preview.refresh(rules) for appearance step' 'No direct accepted evidence for missing-model fallback, PLT candidates, inherited animations and missing-texture diagnostics'

$level = 'src/character_level_up.js'
Map-Group $level @('at','valid') 'NativeLevelUp.rules.row/num plus validation' 'NativeLevelUp.render:344 and source step handlers' 'Source-rule edge and negative parity unverified'
Map-Group $level @('loadLevelUpRules','read') 'NativeLevelUpRuntime.warm_definitions/read_definitions:104-106; Desktop.class_tables_ready' 'Desktop.configure:146 constructs NativeLevelUp and warms definitions' 'Exact 2DA load set/order/failure parity unverified'
Map-Group $level @('levelUpTotal','levelUpClassLevel','initialLevelUpDraft','levelUpAbilities') 'NativeLevelUp.total:145/class_level:149/select_class:176/abilities:184' 'Desktop.panel(level-up):341 -> ServerLevelUp.open -> NativeLevelUp.render' 'No accepted ordinary-player level-up result; class/stat variants unverified'
Map-Group $level @('levelUpSkillBudget','levelUpSkillRule','levelUpSkillBalance','levelUpGrantedFeats','levelUpFeatSlots','levelUpFeatRequirement','levelUpFeatAllows') 'NativeLevelUp.skill_budget_value/budget:200-205, skill_rule:207, balance:210, granted:214, feat_slots:225, feat_requirement:235, feat_allowed:227' 'NativeLevelUp.render:344 consumes rule functions' 'Skill/feat delta and prerequisite parity unverified'
Map-Group $level @('levelUpSpellOptions','levelUpSpellCount','levelUpErrors','levelUpProposal') 'NativeLevelUp.spell_options:293/spell_count:303/errors:315; NativeLevelUpRuntime.finalize/submit:243-260' 'NativeLevelUp.input(level-submit):402 -> Desktop.command -> DirectWorld/Session' 'Proposal byte shape, scroll/domain variants and live acceptance unverified; historical private level-up receipt success=false'

$view = 'src/network_level_up_view.js'
Map-Group $view @('node','button','NetworkLevelUpView','constructor','prepare','warm','reset','cancel','open','current','sync','name','selectClass','render','select','renderFeats','submit') 'ServerLevelUp, NativeLevelUp, NativeLevelUpFrontend and NativeLevelUpRuntime' 'Desktop.configure:146 creates NativeLevelUp; Desktop.panel(level-up):341 opens; Desktop.receive:1426 routes result' 'Seven-page visual/action parity, warm timing, outbound proposal and live acceptance unverified'

$ledger.sourceInventory.reviewedFunctionCount = @($ledger.moduleRecords | ForEach-Object { $_.functions } | Where-Object { $_.status -ne 'pending' }).Count
$ledger.sourceInventory.mechanicalCandidateCount = @($ledger.moduleRecords | ForEach-Object { $_.functions }).Count
$ledger.inventoryStatus = 'mechanical pending inventory with partial creator/level-up maps; no whole-runtime completion claim'
[IO.File]::WriteAllText($LedgerPath, (($ledger | ConvertTo-Json -Depth 30) + "`n"), [Text.UTF8Encoding]::new($false))
Write-Output (@{modules=$ledger.moduleRecords.Count;functionRows=$ledger.sourceInventory.mechanicalCandidateCount;reviewedRows=$ledger.sourceInventory.reviewedFunctionCount} | ConvertTo-Json -Compress)

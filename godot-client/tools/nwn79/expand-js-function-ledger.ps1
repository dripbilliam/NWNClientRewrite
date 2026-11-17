param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$LedgerPath = (Join-Path $PSScriptRoot 'js-runtime-function-ledger-v1.json')
)

$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $ProjectRoot '..')).Path
$ledger = Get-Content -LiteralPath $LedgerPath -Raw | ConvertFrom-Json -AsHashtable

function Source-Line([string]$oldPath, [string]$symbol, [bool]$classMethod = $false) {
    $path = Join-Path $workspace ($oldPath -replace '/', '\')
    $lines = [System.IO.File]::ReadAllLines($path)
    $escaped = [regex]::Escape($symbol)
    $pattern = if ($classMethod) { '^\s{2}(?:async\s+)?' + $escaped + '\s*\(.*\)\s*\{' } else { '^\s*(?:(?:export|async|static|get|set)\s+)*(?:(?:const|function)\s+)?' + $escaped + '\s*(?:=|\()' }
    $hits = @()
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match $pattern) { $hits += ($i + 1) }
    }
    if ($hits.Count -ne 1) { throw "Expected one declaration for ${oldPath}::${symbol}; found $($hits.Count)" }
    return "$oldPath`:$($hits[0])"
}

foreach ($module in $ledger.moduleRecords) {
    foreach ($row in $module.functions) {
        $row.oldLocation = Source-Line $module.oldPath $row.oldSymbol
        $row.oldQualifiedSymbol = if ($row.kind -eq 'export' -or $row.kind -eq 'function' -or $row.kind -eq 'private function') { $row.oldSymbol } else { "$($module.oldPath)::$($row.oldSymbol)" }
    }
}

function Add-Class([string]$oldPath, [string]$className, [string]$oldCaller, [array]$groups) {
    $rows = @()
    foreach ($group in $groups) {
        foreach ($symbol in $group.symbols) {
            $rows += [ordered]@{
                oldSymbol = $symbol
                oldQualifiedSymbol = "$className.$symbol"
                oldLocation = Source-Line $oldPath $symbol $true
                kind = 'class method'
                status = 'pending'
                godotReplacement = $group.candidate
                actualGodotCaller = ''
                evidence = @()
                gap = $group.gap
            }
        }
    }
    $ledger.moduleRecords += [ordered]@{
        oldPath = $oldPath
        sourceState = 'retained'
        oldCallerChain = $oldCaller
        moduleDisposition = 'function inventory only; retain pending caller and branch parity'
        functions = $rows
    }
}

if (-not ($ledger.moduleRecords | Where-Object oldPath -eq 'src/character_frontend.js')) {
    Add-Class 'src/character_frontend.js' 'CharacterFrontend' 'src/main.js:715 constructs; :727,:958,:2659 choose, including server Create' @(
        @{symbols=@('constructor','choose','finish','render','renderSelector');candidate='NativeCharacterLobby state/apply_state/choose_native/close_native; NativeCreation.open/cancel';gap='Local selection and exact method caller/branch parity unverified; source I covers server create only'},
        @{symbols=@('importFiles','download');candidate='Godot local character catalog/import/export candidate';gap='Exact Godot caller and local BIC import/download parity unverified'},
        @{symbols=@('name','description');candidate='NativeCreation title and TalkText candidate';gap='Exact Godot caller and localized fallback parity unverified'},
        @{symbols=@('renderCreator','choiceList','select','input','counter','renderFeats','renderSpells','colourPicker');candidate='NativeCreation.render/render_feats; NativeCreationFrontend.bind_* and source-step controls';gap='Physical source-I Fighter creation covers only one path; method caller and all choice branches unverified'},
        @{symbols=@('resetChoices','recommend');candidate='NativeCreation commit/edit_source_* and package recommendations';gap='Recommendation and reset branch parity unverified'},
        @{symbols=@('save');candidate='NativeCreation.begin_build -> CreationBic.build -> DirectWorld subtype19';gap='Server create passed source I; old local-vault save disposition and exact Godot caller unresolved'},
        @{symbols=@('fail');candidate='NativeCreation.result/set_phase';gap='Error and recovery parity unverified'},
        @{symbols=@('portrait');candidate='NativeCreationFrontend.bind_portraits; NativeCreationPreview; NativeCharacterLobby.warm_portraits';gap='Portrait fallback and availability branch parity unverified'}
    )
}

if (-not ($ledger.moduleRecords | Where-Object oldPath -eq 'src/game_ui.js')) {
    Add-Class 'src/game_ui.js' 'GameUI' 'src/main.js:527 constructs; later method callers require edge inventory' @(
        @{symbols=@('constructor','attach','attachFrontend','detach','loadLanguage','mode');candidate='NativeGameplayUI.configure/set_gameplay_visible/close; TalkText';gap='Frontend attach and language loading exact caller/parity unverified'},
        @{symbols=@('open','toggle','close','conversationChanged','closeAll','syncCharacterSheet','receiveInventoryMessage','renderPanel');candidate='NativeGameDesktop.panel; NativeGameplayUI.receive; ServerConversation; NativeInventory';gap='Panel stack, cutscene, capture and exact method caller parity unverified'},
        @{symbols=@('notify','message','request','art','positionedArt','buildHud','updateLog','refresh','updateActionQueue','loadPortrait','ruleName','objectName');candidate='GameplayUI speech/present/request; NativeUIArt; Desktop sync; Chat/portrait/TalkText';gap='Mixed request, art and HUD branches need exact Godot caller and parity evidence'},
        @{symbols=@('updateQuickbar','quickbarPage','writeQuickbarDrag','makeQuickbarSource','configureItemShortcut','assignQuickbar','saveQuickbarLayout','quickbarDescription','quickbarIcon','quickbarChoices','useQuickbar');candidate='ServerQuickbar; NativeGameDesktop.refresh_quickbar/assign/activate';gap='Drag, persistence, restore and exact method caller branches unverified'},
        @{symbols=@('worldSpellMenu','itemUseEntries','worldAbilityMenu');candidate='NativeGameDesktop.spell_entries/ability_entries/item_menu_ability';gap='Menu branch and actual Godot caller parity unverified'},
        @{symbols=@('key');candidate='NativeGameDesktop._unhandled_key_input; NativeMainMenu Esc';gap='Esc headless check passed; remaining keyboard branches and exact caller parity unverified'},
        @{symbols=@('dialogueText','renderConversation','renderJournal','inventoryItemButton','renderInventory','renderCharacter','spellBookChoice','renderSpells','renderPreparation','dropPreparedSpell','preparationWidgetCurrent','renderExamine','renderOptions','drawMap','renderNative','nativeStatus','nativeAction');candidate='Godot Conversation/Journal/Inventory/CharacterSheet/Spellbook/Examine/Map/MainMenu owners';gap='Function-specific Godot caller and full branch parity not established'}
    )
}

$ledger.retiredModuleSource.functionExpansionComplete = $false
$ledger.inventoryStatus = 'in-progress; no whole-runtime completion claim'
$json = $ledger | ConvertTo-Json -Depth 30
[System.IO.File]::WriteAllText($LedgerPath, $json + "`n", [System.Text.UTF8Encoding]::new($false))
Write-Output "modules=$($ledger.moduleRecords.Count) functionRows=$((@($ledger.moduleRecords | ForEach-Object { $_.functions })).Count)"

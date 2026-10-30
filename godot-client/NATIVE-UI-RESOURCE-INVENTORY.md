# Original UI resource inventory — implementation ledger

The native installed-catalog scan found **104 GUI2047 resources and 1,243 controls**. All 104 parsed successfully. This is a complete metadata scan of that catalog, not an exhaustive runtime UI/action inventory or a parity pass. Programmatic controls, nested internal widgets, conditional roles and server-authored NUI require separate inspection. Every row below still needs its complete control/action/state audit, including resources that already have scoped native checkpoints.

Source report: `reports/native-ui-resources-inventory-v1.json`; debugger receipt: `native-ui-resources-inventory-v1.debugger.json`. It records resource hashes, each control's tree path/tag/type/model, caption font/reference/color fields, geometry and available field names. No original pixels or resolved TLK strings are exported. Its `checks:104` counts parsed resources, not tested UI actions.

Reproduce with `tools/test-native-kernel-debugger.ps1 -Run UNIQUE -Script res://tools/inspect_native_ui_resources.gd -TestArguments @('--install=INSTALL')`. Use a fresh report name. Native parsing is read-only; no public connections.

Observed type counts:0=30,1=110,2=83,3=109,5=354,6=24,8=151,9=382. These include model regions, buttons, checks, panels, labels, sliders, edits and text buttons; individual semantics must come from original code. Caption fonts in these resources are Galahad14 (878 uses), dialog16x16 (7) and chat01 (2). Other programmatic fonts are outside this set.

| Original resource | Controls including root | Area | Full parity |
| --- | ---: | --- | --- |
| `buysell_confirm` | 4 | Merchant | Unverified |
| `cg_alignment` | 15 | Creation / level-up | Unverified |
| `cg_appearance` | 13 | Creation / level-up | Unverified |
| `cg_attributes` | 35 | Creation / level-up | Unverified |
| `cg_char_info` | 15 | Creation / level-up | Unverified |
| `cg_class` | 7 | Creation / level-up | Unverified |
| `cg_domain` | 8 | Creation / level-up | Unverified |
| `cg_familiar` | 8 | Creation / level-up | Unverified |
| `cg_featinfo` | 5 | Creation / level-up | Unverified |
| `cg_feats` | 12 | Creation / level-up | Unverified |
| `cg_feats_popup` | 5 | Creation / level-up | Unverified |
| `cg_levup_attrib` | 33 | Creation / level-up | Unverified |
| `cg_lvlup_summary` | 5 | Creation / level-up | Unverified |
| `cg_main` | 14 | Creation / level-up | Unverified |
| `cg_package` | 8 | Creation / level-up | Unverified |
| `cg_portrait` | 5 | Creation / level-up | Unverified |
| `cg_race` | 8 | Creation / level-up | Unverified |
| `cg_school` | 15 | Creation / level-up | Unverified |
| `cg_sex` | 7 | Creation / level-up | Unverified |
| `cg_skills` | 13 | Creation / level-up | Unverified |
| `cg_spellinfo` | 4 | Creation / level-up | Unverified |
| `cg_spells` | 24 | Creation / level-up | Unverified |
| `directconnect` | 9 | Connection / transfer | Native source/input and owned local admission checked; pixels reviewed at1 scale; full parity open — NATIVE-CONNECTION-UI.md |
| `dm_chooser` | 18 | DM tools | Unverified |
| `dm_creator` | 5 | DM tools | Unverified |
| `dm_searchbytag` | 15 | DM tools | Unverified |
| `dth_deathopts` | 7 | Death / respawn | Unverified |
| `entercdkey` | 17 | Auxiliary / confirmation / identity | Unverified |
| `examine_basic` | 5 | Examine | Unverified |
| `examine_item` | 6 | Examine | Unverified |
| `ingame_barter` | 14 | Barter | Unverified |
| `ingame_opts_vid` | 30 | Options / key bindings | Unverified |
| `ingame_portal` | 7 | Connection / transfer | Unverified |
| `ingame_pvp` | 13 | PvP / player relations | Scoped native frame/input and two-peer server actions; full parity open |
| `ingame_store` | 9 | Merchant | Unverified |
| `inv_container` | 8 | Inventory / container / amounts | Unverified |
| `inv_equip` | 17 | Inventory / container / amounts | Unverified |
| `inv_panel` | 8 | Inventory / container / amounts | Unverified |
| `inv_stacksplit` | 9 | Inventory / container / amounts | Unverified |
| `jnl_page_notes` | 2 | Journal / world notes | Native frame/editing persistence scoped; full audit open |
| `jnl_page_quest` | 7 | Journal / world notes | Native frame/local quest lifecycle scoped; full audit open |
| `jnl_page_world` | 8 | Journal / world notes | Unverified |
| `jnl_panel` | 3 | Journal / world notes | Native frame/input scoped; full audit open |
| `jnl_wld_dm_new` | 5 | Journal / world notes | Unverified |
| `load_screen` | 5 | Loading | Unverified |
| `map_area` | 8 | Map / pins | Unverified |
| `map_mini` | 4 | Map / pins | Unverified |
| `map_pin_text` | 6 | Map / pins | Scoped native editor/input and local-server note lifecycle; full parity open |
| `multi_login` | 10 | Multiplayer account | Native source/input,781 original validation cases, default-name persistence and local admission checked; full parity open — NATIVE-CONNECTION-UI.md |
| `multi_newacct` | 16 | Multiplayer account | Unverified |
| `okcancelpanel` | 4 | Auxiliary / confirmation / identity | Native original artwork/bounded-label, result/Escape and owned local Delete checks — NATIVE-LOCAL-CHARACTER-DELETION.md; complete live IPC, sound/keys/scales remain open |
| `okpanel` | 3 | Auxiliary / confirmation / identity | Unverified |
| `okscrollpanel` | 3 | Auxiliary / confirmation / identity | Unverified |
| `options_adv_srv` | 34 | Options / key bindings | Unverified |
| `options_adv_vid` | 27 | Options / key bindings | Unverified |
| `options_advsound` | 15 | Options / key bindings | Unverified |
| `options_controls` | 21 | Options / key bindings | Unverified |
| `options_feedback` | 26 | Options / key bindings | Unverified |
| `options_game` | 21 | Options / key bindings | Unverified |
| `options_gorepass` | 10 | Options / key bindings | Unverified |
| `options_key_page` | 5 | Options / key bindings | Unverified |
| `options_key_pnl` | 7 | Options / key bindings | Unverified |
| `options_main` | 13 | Options / key bindings | Source/callback/native data plan; visible owner and full actions/parity open |
| `options_pregame` | 10 | Options / key bindings | Source/callback/native data plan; visible owner and full actions/parity open |
| `options_sound` | 32 | Options / key bindings | Unverified |
| `options_srv` | 17 | Options / key bindings | Unverified |
| `options_sup_adv` | 25 | Options / key bindings | Unverified |
| `options_video` | 24 | Options / key bindings | Unverified |
| `options_vidmodes` | 14 | Options / key bindings | Unverified |
| `party_invitation` | 7 | Party invitation | Scoped native popup, preference/reply input and original-server lifecycle; full parity open |
| `player_profile` | 13 | Auxiliary / confirmation / identity | Source/name-policy/input/local-admission checkpoint; full roles/scale/parity open — NATIVE-CONNECTION-UI.md |
| `playerpassword` | 5 | Auxiliary / confirmation / identity | Native source/input, masking and scoped join checked; full role/visual audit open — NATIVE-SERVER-DETAILS.md |
| `pnl_pre_demsplsh` | 1 | Entry / campaign / load / save | Unverified |
| `pre_camp_movies` | 9 | Entry / campaign / load / save | Unverified |
| `pre_campaign` | 8 | Entry / campaign / load / save | Unverified |
| `pre_char_version` | 19 | Entry / campaign / load / save | Unverified |
| `pre_chartype` | 4 | Entry / campaign / load / save | Unverified |
| `pre_loadgame` | 13 | Entry / campaign / load / save | Unverified |
| `pre_loadgamem` | 13 | Entry / campaign / load / save | Unverified |
| `pre_loadmod` | 6 | Entry / campaign / load / save | Unverified |
| `pre_loadmodm` | 6 | Entry / campaign / load / save | Unverified |
| `pre_main` | 8 | Entry / campaign / load / save | Source/callback/native data plan; visible owner and full actions/parity open |
| `pre_motd_popup` | 7 | Entry / campaign / load / save | Unverified |
| `pre_movies` | 14 | Entry / campaign / load / save | Unverified |
| `pre_multiplayer` | 7 | Entry / campaign / load / save | Source modal/navigation/input/local-admission checkpoint; hosting/LAN and full parity open — NATIVE-MULTIPLAYER-ENTRY.md |
| `pre_newgame` | 9 | Entry / campaign / load / save | Unverified |
| `pre_newgamem` | 9 | Entry / campaign / load / save | Unverified |
| `pre_playerinfo` | 13 | Entry / campaign / load / save | Unverified |
| `pre_playmod` | 10 | Character selection | Source frame/rows, partial record, Server Info/Player List owners/protocol and scoped native/local checks; complete record/editing/keyboard/role/scale/original comparison open — NATIVE-CHARACTER-LOBBY.md and NATIVE-LOBBY-PAGES.md |
| `pre_playmod_chat` | 3 | Entry / campaign / load / save | Unverified |
| `pre_savegame` | 13 | Entry / campaign / load / save | Unverified |
| `pre_savename_pop` | 5 | Entry / campaign / load / save | Unverified |
| `server_connect` | 3 | Connection / transfer | Unverified |
| `serverlist_chat` | 12 | Server browser | Unverified |
| `serverlist_filt` | 11 | Server browser | Source/native input/persistence and modern row-filter oracle checked; full visual/key/scale/role parity open — NATIVE-SERVER-FILTERS.md |
| `serverlist_lan` | 19 | Server browser | Unverified |
| `serverlist_page1` | 29 | Server browser | Source page/columns/scrolling and scoped actions checked; game-type filtering and full parity open — NATIVE-SERVER-PAGES.md |
| `serverlist_page3` | 18 | Server browser | Source History geometry/input checked; full behavior/visual parity open — NATIVE-SERVER-PAGES.md |
| `serverlist_page4` | 18 | Server browser | Source Favorites geometry/input and explicit Add/Remove checked; full parity open — NATIVE-SERVER-PAGES.md |
| `serverlist_page5` | 29 | Server browser | Unverified |
| `serverlist_panel` | 6 | Server browser | Source three-tab ownership/navigation checked; platform/role/full parity open — NATIVE-SERVER-PAGES.md |
| `srv_srvdetails` | 41 | Server browser | Native source/extended data/navigation/password input scoped; unbounded-caption headless fix prepared, graphical follow-up pending — NATIVE-SERVER-LIST-INPUT.md |
| `util_editpopup` | 5 | Auxiliary / confirmation / identity | Unverified |
| `yesnocancelpanel` | 5 | Auxiliary / confirmation / identity | Unverified |

## Programmatic surfaces are a separate obligation

Metadata/research source checkpoint: `backups/native-ui-inventory-v1.zip`.
Read-only coverage audit: `node godot-client/tools/audit-native-ui-inventory.mjs`.
This preserves the preceding functional scroll-input implementation and adds
the inventory tools/documentation; it does not add a native character frame yet.

The original character sheet has no GUI2047 file in this catalog. Its native `CPanelCharSheet` constructor at 14088a0a0 selects `PNL_CHRSHT` for the game and `PNL_CHRSHT2` for the non-resizable selection variant. The game has three page buttons; the latter variant adds a fourth. Character page selection at 14088a830, Skills at 14088a970 and Feats at 14088a8e0 instantiate their pages lazily. The ordinary native control model remains the server subscription source; this research does not change available characters or disclosure.

`reports/native-record-models-inventory-v1.json` records 21 original model hashes, bounds, hooks and animation names using the native decoder. The Character page is assembled by `CCharPageChar` at 1409b3440 from source hooks for race/alignment/classes, six scores/modifiers/labels/icons, AC, HP, XP, next level, detail list and Level Up. Evidence is retained in `../backups/animations/rea-native-character-frame-research-v1.json`. The 31,360-character constructor projection was retrieved completely from retained REA evidence after the full dossier exceeded transport capacity; coverage is recorded. These are static observations, not original-client execution.

**Do not size a character window from every page mesh's full bounds.** `PNL_CHRSHT` is a 360×59 header with a resize-bar hook near 468; `PNL_CHRSHT_CHAR` includes a background extending to 3,455 pixels. The visible page must use the original height/viewport rules. Rendering a bounded source region at native pixel density needs investigation before reusing the shared whole-model raster path: its 2048-pixel cap would reduce density on this tall model. Arbitrarily squeezing the entire page into a window is not parity.

The HUD/party/action queue/chat/quickbars, radial trees, spellbook, creature record variants, tooltips and NUI also need original-code/resource inventories; absence from this table cannot retire them. The [native character-sheet frame/pages](NATIVE-CHARACTER-FRAME.md) now have a scoped original-art/input milestone. Full content, disclosure, resizing, states and original-client comparison remain open; its passing narrow checks do not change this ledger's full-parity status.

# Multiplayer inventory presentation, 2026-10-20

Target: original NWN:EE89.8193.37-17 x64, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The binary/project remain read-only. No proprietary models, textures or binaries
are copied into the workspace. Fixture PNGs are rendered UI screenshots.

The user requested the supplied equipment/backpack arrangement and item icons,
with creature equipment hidden by default. The user explicitly placed the
creature-slot switch in Options, not in the inventory itself.

## Implemented presentation

The multiplayer inventory now has an equipment diagram above a10x6 backpack,
six page selectors, stack counters, native empty-slot silhouettes, native close
art and an examine mode. Existing typed server requests still own equipment,
move, container and store operations. Invalid equipment destinations are filtered
using the active base-item slot mask; nothing changes ownership locally.

The normal14 slots are always displayed. Options' “Show creature equipment
slots” exposes flags1<<14 through1<<17. Its default is false and an explicitly
chosen value persists as a local UI preference. There is no checkbox in the
inventory window. This does not alter server equipment or slot indices.

Diagram positions follow the user's reference screenshot; they are CSS layout,
not a claim that all original GUI control coordinates/resizing were recovered.
Native slot-link data at140e4ffb0..140e501b8 confirms normal slot flags, icon
dimensions and inv_slot_* resource names. Sources are active server resources.
Containers/stores retain paired panes; their item icons share this renderer.
Item shortcuts also use the shared item-icon descriptor instead of returning a
permanent “item icon unhandled” placeholder.

## Original icon construction

UpdateIcons14083f6f0 selects CGuiIcon for model type0, CLayeredIcon for1,
CCompositeIcon for2 and CArmorIcon for3. GetIconResRef14029dc80 supplies native
resource formatting, already checked by the existing252 naming cases.
Scroll75 uses the cast-property's iprp_spells Icon; cloak80 uses cloakmodel ICON.
Those special table branches are source-mapped; they are not separately covered
by the new32-case oracle.

Armor uses CAPart names6/7/8/14/15/18, IP + gender + underscore, and numbered
part IDs. Robes use the named HIDEPELVIS/HIDECHEST/HIDEBELT/HIDESHOR/HIDESHOL
columns. Six palette rows preserve native per-part selection, including the
shoulder palette order15/14.255 selects the item's base color. Both icon metal
channels use native palette type3. Existing PLT palette-row decoding is reused;
broader world palette/lighting parity remains separate.

CGuiIcon::CreateCopyIconModel1401e3b00 and CLayeredIcon1401e3c80 choose
GUI_ICON_WXHL. Composite1401e3930 chooses GUI_ICON_WXHLC and replaces three
texture slots. Armor1401e3920 calls LoadArmorLayeredIconModel1401e4470,
which compacts existing PLTs and chooses GUI_ICON_ARMRnL. It assigns palettes
by compact index, and falls back to SZ_DEFAULT_ARMOR_TEXTURE=ipm_chest001
(pointer14128f288 ->140daf4c0). The shared unlit GUI-model rasterizer now builds
these models with resolved item images/PLTs, not generic equipment pictures.

32 original UpdateIcons cases execute native branches, names and palette loops
until the appropriate icon constructor. Resource existence, table getters,
allocation/string services and constructors are captured boundaries. No GPU or
complete error/destructor-path claim follows from that oracle. The first capture
used a raw CResRef copy at the CExoString overload; this was corrected before
comparing production recipes. All32 final cases agree.

## Server fields and lifecycle

Client player reader1407b4f70 maps transmitted player898 to client1b8 (gold)
and player978 to client28c (carried decipounds). Inventory refresh140856fa0
formats gold with TLK1907, rounds carried decipounds with floor(float/10+.5),
and reads active encumbrance Normal using the replicated Strength BYTE.
G/I/U reader1407b3f30 also updates carried weight and Strength. The footer
projects these fields; it does not sum local item weights or invent gold.

Icon and source caches belong to the NativeUiAssets/server resource owner.
Reset discards old artwork; async generation guards reject old completions.
Only visible pages/slots request icons. Item image bytes are excluded from UI
diagnostic metadata. Missing-icon diagnostics are deduplicated. An acknowledged
empty inventory stops saying “Waiting for inventory”. Success does not insert
debug request/completion messages above the equipment layout.

## Validation

-32 native icon recipes plus252 existing original resource-name cases.
-23 focused inventory/container/quickbar checks pass with installed resources.
-Hidden offline Electron uses actual cached Arelith resources: seven item
 widgets render,14 normal slots, four optional slots only via Options, default
 off, native stack24, footer gold/weight, click-through-safe native close art,
 native-coordinate drop request and unchanged canonical objects; zero HTTP.
-Full existing HUD fixture passes spellbook preparation/drag, container
 transfers, character subscriptions, action queue and feedback checks. Its old
 text-only tab selector now uses accessible labels; it waits for asynchronous
 character/journal subscriptions rather than assuming completion after30ms.
-Production build passes. Live acceptance is recorded separately after rollout.

Artifacts: native-item-icons-v1.json, creation-experience-item-icons-oracle-v2.txt,
item-icons-tests-v3.txt, inventory-focused-v3.txt, inventory-ui-v1.json/png,
inventory-ui-run-v4.txt, inventory-hud-replay-v1.json and inventory-build-v3.txt
under backups/animations. Reverse-engineering artifacts use rea-arelith-* names.

This completes the requested inventory presentation slice, not every inventory
feature or multiplayer. Gold splitting, full native resizing/keyboard behavior,
secondary shortcut icon placement and broader UI/material parity remain open.

Live rollout: Yrs reconnected as PID38528, native inventory request acknowledged,
14 normal slots, no creature checkbox in inventory, GP1000,0/150lbs. Server
inventory is empty, so item-icon acceptance here is the offline real-resource
renderer result. No invalid messages or renderer errors. Derived proof is
creation-experience-inventory-live-proof-v1.json. Checkpoint v13 is verified;
this live-rollout note is post-seal. User visual acceptance remains pending.

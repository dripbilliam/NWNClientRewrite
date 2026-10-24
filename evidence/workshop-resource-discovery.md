# Installed Steam Workshop resources

**Updated user policy:** Workshop HAKs are globally active, with per-mod toggles
after selecting the content folder. This supersedes the earlier requested-only
plan below. Enabled local Workshop HAKs are now a separate local archive layer;
the active server's selected NWSync/required HAK layers retain precedence and
their contexts are never reused as another server's local mods. All19 installed
mods default enabled, and disabled IDs persist with the selected folder.
This global activation follows the user's explicit instruction, not a claim
that the complete native Workshop registration order has been reconstructed.

Offline production-resolver verification indexes66 HAKs /208867 entries in
301ms in this run, then reads the seven recovered medium portraits successfully.
Disabling CEP removes its archive indexes and those seven image lookups, while
enabled contexts remain intact. The two missing fxpa model references remain
absent. Archive payloads are file-backed and read on demand; the measured
main-process index allocation is about79MB heap/111MB RSS, not gigabytes of
eager asset copies. These are single-run observations, not live FPS claims.

User steering identified Steam Workshop as another installed-content source.
The read-only inventory follows local Steam library metadata and NWN app704450
content. It finds19 installed items,86 ERF/MOD/HAK archives and1505 loose
portrait files. Only archive headers/key tables and filenames are recorded;
resource payloads are not copied, subscriptions/downloads are unchanged and
no remote game server is joined.

Seven previously absent portrait bases occur in installed CEP Workshop item
2670483287: ogreoni01_, ogreoni06_, ogreoni07_, ogreoni08_, ogreoni09_,
annis_ and orccaptain_. These are HAK entries, not loose portrait files. They
must not be globally mounted into unrelated servers merely because they exist.
The prior statement that these images were absent was limited to the downloaded
server catalog and scanned install/profile directories; Workshop adds a source.

Read-only target remains the pinned NWN:EE89.8193.37-17 x64 executable, SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
Native CSteamInternal::GetWorkshopPathsForAlias208310 calls GetSubdirForAlias
207ee0 at20838e and joins installed-item paths with an alias-specific subdir,
checking existence. CExoBase::GetDirectoryAndWorkshopList115080 invokes
CSteam::GetWorkshopPathsForAlias2043c0 at1151c4 after normal directory listing.
ResolveWorkshopFilename209570 searches installed paths for the requested alias,
basename and resource extension. Ghidra's hidden return/string ABI in207ee0
is incomplete in pseudocode, so its apparent empty return is not a valid alias
mapping specification. Subscription order, resource registration priority and
complete alias fallback still need evidence before runtime integration.

The user requests Main Menu configuration for the mods folder, preset to the
detected default, and persistent Windows-protected CD-key storage. That key
should remain in the client profile, never the public mods folder, logs or
renderer readback. The user explicitly selected protected profile storage.
Main Menu Options is currently a placeholder; implementation follows the
movement checkpoint. Goal remains active.

That historical placeholder is now implemented and validated; see
`main-menu-client-settings.md` and the settings UI/resource proofs.

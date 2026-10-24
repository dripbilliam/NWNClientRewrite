# Installed portrait directory registration

Target: NWN:EE89.8193.37-17 x64, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Read-only input: `../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`.

`CExoResMan::SetupDefaultSearchPath` at `0x1401947b0` registers
`PORTRAITSINSTALL:` at90,000,000 with callback `0x1401972f0`, then
`PORTRAITS:` at91,000,000 without a callback in client mode. Relevant string
references are `0x1401950dc`/`0x1401950e6` and
`0x140195159`/`0x140195165`; these are string-reference instructions, not
asserted AddKeyTable call addresses. The installed default alias string is
`\data\prt` at `0x140d9ca28`. Successful REA evidence is retained in
`rea-installed-default-resource-dirs-v1.json` and
`rea-installed-portrait-alias-search-v2.json`.

The original24-byte callback at `0x1401972f0..0x140197307` accepts only
resource types3(TGA) and2033(DDS). The mapped-code Unicorn oracle executes
all65,536 unsigned-short inputs and confirms exactly those two. This is
original instruction execution with a typedR8 boundary, not a live native GUI.
`rea-installed-portrait-filter-bytes-v1.json` and
`native-installed-portrait-filter-v1.json` retain the evidence. The failed
attempt to analyze this callback as a defined Ghidra function is not used as
evidence or included in the checkpoint.

The resolver now lazily indexes flat `data/prt` image entries before server
content. User portrait images have91M priority and installed images90M;
server40M, HAK30/31M, module22/23M, override12M and installed KEY1/2/3M
retain their existing ordering. Only selected image bytes are read. A selected
source read failure remains a failure and cannot silently substitute a lower
source. The existing user-folder image restriction remains deliberate:
unlike the native unfiltered user registration, it cannot introduce rules.

The current install contains35 TGA files in that directory. Six selected
portrait rows previously missing from both the cached catalog and authorized
profile folder are recovered: exornova_, skandii_, heavyline_, lanteri_,
aragnosh_ and seafaref_. Coverage becomes329/356;27 remain unavailable in the
inspected contexts. All six are selected from PORTRAITSINSTALL and decode to
nonblank64x100 images in the actual creator fixture. No asset files are copied
into this workspace. The14 ERFs in installed data/txpk have160-byte headers
and zero entries; no texture-pack resource layer was added for empty archives.

Validation:37 focused resource/cache/creator checks pass, including distinct
serverA/B rules, image-only folder admission, priority and selected-source
failure. Creator-v19 passes all15steps, scroll, feat filtering/groups, voice
and custom appearance checks. Lifecycle-v6 passes19 cases. Built main-v5
uses index-DR_H7-HZ.js and successfully reads an installed portrait through
production preload/trusted IPC, retaining typed missing/invalid-ref behavior.
There are zero game joins/content fetches; the debug Google Fonts request is
cancelled before sending. These offline checks do not interrupt the live local
movement client or connect to a remote server.

`creation-experience-installed-portraits-proof-v1.json` hashes current sources
and the bounded reports. The overall goal remains active: the27 missing image
sources, observed effect bitmap gaps, physical-key feedback and broader dense
animated/replicated/fullscreen performance checks remain open.

Verified checkpoint v25:1344files/53880958bytes, SHA256221007fe26fd8e6e1a6068b7c0a9731474a69bba2247f10f4842cbf165eb5e84. Independent audit:53parents,191required entries, zero missing/newcredential candidates. This verification is post-seal.

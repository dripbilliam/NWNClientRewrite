# Missing attunement comparison

The user reported that Dexina Cain's original-client examine contains “Attuned to Fire”, while the replacement still lacks it after the color fix. This line was already absent in the earlier replacement screenshot. The preceding token fixture authored the line from the original screenshot to test rendering; it did not establish that the replacement received it.

## Observed inputs

The user copied the current replacement `.network-examine.dataset.state` directly from DevTools. It is a27/3 creature examine, target4294967086, Dexina Cain, custom portrait65534/`po_clsbard_`, condition0/reaction1. Its literal description begins with two newlines, then colored “Racial Type: Human”, then Strength/Average, Dexterity/Very High, Constitution/High and Charisma/High. There is no attunement string, StrRef or CUSTOM token for that line, and no `effects` list. Rendering cannot recover the absent information from this message.

The user explicitly offered live original-client observation, connected it and left Dexina examined. The running original process49416 is Steam's nwmain.exe, ASLR base0x7ff7e3340000, SHA256 `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`, matching read-only research build89.8193.37-17.

`scripts/read-native-examine-memory.ps1` requests only PROCESS_QUERY_INFORMATION|PROCESS_VM_READ (0x410), scans committed private PAGE_READWRITE regions for two exact gameplay strings and serializes only bounded NUL-terminated suffixes of matching strings. No write/protect/thread/debug/injection APIs are used, no authentication material or unrestricted memory dump is saved, and the process handle is closed. It scanned1311136768 bytes across1409 regions in5619ms and found four matching buffers. `backups/animations/native-examine-live-strings-v1.json` retains derived observations.

Two original buffers contain “Attuned to Fire”; one continues into the same racial/ability lines seen in the replacement description. This establishes that the original holds that text, not that the replacement formatter removed it. The scan is not a decrypted packet capture and does not itself identify every buffer owner or prove identical server requests/character state. The original process was not modified or stopped.

## Relevant Arelith rule

Follow-up: the user initially confirmed the same character/state, then identified
the server-side feat check and explicitly paused testing to prepare another
character. No further attunement testing should run until requested. Before that
pause, the bounded retained-buffer scan captured an original27/3 envelope:
the first279 bytes of the285-byte candidate in native-examine-live-strings-v2.json
decode successfully with the existing decodeServerGameMessage, retaining the
colored Attuned to Fire line and the matching racial/stats text. Our decoder
preserves the line when supplied; the earlier replacement reply lacked it.
Two bounded live receiver polls captured no examine packet and do not count as
successful captures. No product fix was made for this.

[Arelith's Feat changes, Spell Focus: Divination](https://wiki.nwnarelith.com/Feat_changes#Spell_Focus:_Divination) documents that this feat reveals Life/Death/Fire/Water/Earth/Air attunement through Right Click → Examine. The primary wiki's indexed text was retrieved via web search on2026-10-21; direct opening returned403. It supports examiner-dependent disclosure rather than universal client-side display. The later user confirmation and explicit testing pause are recorded above.

The working inference is a difference in examiner eligibility/server-provided text. No attunement label has been hardcoded, granted or synthesized, and no product change was made on this inference.

## Additional native checks

Read-only analysis `rea-examine-effect-list-v1.json` at0x1408961d0 confirms the separate disclosed-effect path requires active effecticons Icon and StrRef entries, appends resolved text and creates CTL_EXAMIN_EFECT GUI children. The user's current replacement message has no such list. `rea-examine-effect-description-v1.json` at0x140897820 clears those GUI children. `rea-examine-live-panel-getter-v1.json` at0x1406abbc0 returns `*(*(arg+8)+0x90)`. These new captures do not modify binary/Ghidra state or establish complete renderer/protocol parity.

No automated Arelith input, joins, chat or character uploads were performed. The user manually connected/examined in the original client. The broader goal remains paused; this is unsealed research after checkpointv49.

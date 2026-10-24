# Movement closeout before core-feature pivot — 2026-10-18

User deferred additional movement polish. This records changes already in
progress at that redirect; subsequent work moved to multiplayer Examine.
Build hashes and native target are the same as multiplayer-examine.md.
No original binaries or Ghidra projects were modified.

inspect-native-network-gait.py executes original1408114d0 path/correction
owners and captures model+0x80 playback speed. Native script movement applies
the server factor to both travel and gait. The replacement formerly applied
it only to travel. network_gait.js now uses the verified f32 calculation,
installed WALKDIST/RUNDIST and parsed clip length, preserving creeping's
special rate. Original cases2916 vary rate, script/factor, scale, animation,
clip length, acceleration and stride. All match. Previous-animation clip
blending and nonidentity visual-transform rendering remain unproven.

inspect-native-network-correction.py executes complete140804840 and actual
creature PlayAnimation1407fc7d0. Vtable140e474e8+0x150 resolves that owner;
correction-start140807670 stores512.208 cases capture final setters and
real queue requests. Corrections use XY distance: squared>=16 snaps;
tiny error<1e-5 snaps. Otherwise elapsed time decrements the512ms timer.
Idle0/1 with squared error>=.04 requests type6 directional step24..27.
Dot thresholds are ±.707; exact zero cross chooses27. Remaining timer is
WORD duration; queue rate is clipMilliseconds/duration, null action, delay0.
Native turns80..83 also queue with null action and replicated speed.

network_motion.js computes correction on the next presentation frame;
network_movement_cue.js and network_combat_presentation.js queue native
step/turn requests and restore base playback. Canonical packet state remains
unchanged. Removed an earlier packet-time origin/3D snap shortcut which did
not follow the original XY check. Path completion keeps visual base in sync.
Unavailable movement clips are recorded instead of silently substituted.

Oraclev1 missed the tail; v2 completed804840; v3 reached a missing free stub
in PlayAnimation; v4 completed both owners,208cases pass. JS tests initially
used double9.8 instead of original f32 input and opposite zero-cross sign;
corrected to the observed native values. Failures retained. Gait/correction
focused v4:28 tests pass, including existing3933 movement oracle cases.
Final Examine focused v5 also covers these owners; buildv3 passes. Live v93
did not report unavailable cues/errors, but did not intentionally induce each
step/turn clip. No claim of full movement smoothness or visual cue parity.

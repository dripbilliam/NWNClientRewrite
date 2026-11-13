extends RefCounted
# Finite diagnostic labels only. Never retain untrusted names or message payloads.
const KINDS=["raw-world-begin","raw-world-chunk","raw-world-end","ui-protocol","raw-visual-events","raw-combat-events","raw-voice-events","raw-script-sounds","lobby","session-reset","setup","movement","drive-ack","native-clock-protocol","raw-tile-visibility","raw-creature-visibility-permission","replay-movement-input","replay-view","begin-performance-window","finish","finish-ack"]
static func message_kind(kind: String) -> String:
	return kind if kind in KINDS else "other"

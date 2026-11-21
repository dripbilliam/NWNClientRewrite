extends RefCounted
# Direct translation of client_attack_sound.js selection flow805d20.
# The caller supplies the same table, equipment, cosmetic RNG, and one-shot
# providers used by NetworkCombatPresentation.sound().
static func _failure(p: Dictionary) -> Dictionary:
	var reason: String=str(p["providerError"].call())
	return {} if reason.is_empty() else {"played":false,"error":reason}

static func _appearance_sound(actor: Dictionary, p: Dictionary) -> int:
	var appearance: int = int(p["appearance"].call(actor))
	if not str(p["providerError"].call()).is_empty():return 0
	return int(p["int"].call("appearance", appearance, "SoundAppType").value)

static func _held(actor: Dictionary, record: Dictionary, p: Dictionary) -> Variant:
	var attack_type := int(record.get("weaponAttackType", 0))
	var slot: Variant = 32 if attack_type == 2 else (16 if attack_type in [1, 6] else null)
	return p["equipped"].call(actor, slot)

static func _material_fallback(actor: Dictionary, record: Dictionary, index: int, p: Dictionary) -> int:
	var item: Variant = _held(actor, record, p)
	return int(p["weaponMaterial"].call(item)) if item != null else index

static func _sound(actor: Dictionary, row: int, column: String, delay: int, p: Dictionary) -> void:
	var resource: Dictionary = p["string"].call("weaponsounds", row, column)
	p["play"].call(actor, str(resource.value), delay)

static func _category(target: Dictionary, p: Dictionary) -> int:
	return int(p["animationCategory"].call(target, int(p["currentAnimation"].call(target))))

static func _miss(actor: Dictionary, record: Dictionary, p: Dictionary) -> Dictionary:
	var appearance: int=_appearance_sound(actor,p)
	var failed:=_failure(p);if not failed.is_empty():return failed
	var entry: Dictionary = p["int"].call("appearancesndset", appearance, "MissIndex")
	failed=_failure(p);if not failed.is_empty():return failed
	var index: int = int(entry.value)
	var row: int = index if bool(entry.found) else _material_fallback(actor, record, index, p)
	failed=_failure(p);if not failed.is_empty():return failed
	var column := "Miss" + str(int(p["random"].call()) % 2)
	var quarter: int = (int(record.get("duration", 0)) & 65535) >> 2
	var draw: int = int(p["random"].call())
	if quarter == 0:
		return {"played": false, "error": "Native attack sound delay divides by zero"}
	_sound(actor, row, column, quarter + draw % quarter, p)
	failed=_failure(p);if not failed.is_empty():return failed
	return {"played": true, "error": ""}

static func select(actor: Dictionary, record: Dictionary, phase: int, p: Dictionary) -> Dictionary:
	if record.is_empty(): return {"played": false, "error": ""}
	var target: Variant = p["object"].call(int(record.get("targetId", 0x7f000000)))
	if not target is Dictionary: return {"played": false, "error": ""}
	var result: int = int(record.get("result", 0)) & 255
	var ranged: bool = int(record.get("ranged", 0)) == 1
	if phase == 1:
		if ranged or (not (result < 11 and bool((0x4ab >> result) & 1)) and _category(target, p) == 0):
			return _miss(actor, record, p)
		return {"played": true, "error": ""}
	if ranged: return _miss(actor, record, p)
	var source_sound: int = _appearance_sound(actor, p)
	var failed:=_failure(p);if not failed.is_empty():return failed
	var animation: int = int(p["currentAnimation"].call(actor))
	var columns := {200: "WeapTypeL", 263: "WeapTypeL", 201: "WeapTypeR", 264: "WeapTypeR", 202: "WeapTypeS", 265: "WeapTypeS", 204: "WeapTypeClsLw", 203: "WeapTypeClsH", 205: "WeapTypeRch"}
	var column: String = str(columns.get(animation, "WeapTypeL"))
	var weapon: int = int(p["int"].call("appearancesndset", source_sound, column).value)
	failed=_failure(p);if not failed.is_empty():return failed
	if weapon == 0: weapon = _material_fallback(actor, record, weapon, p)
	failed=_failure(p);if not failed.is_empty():return failed
	if weapon == 19 and result != 4:
		_sound(actor, weapon, "Miss" + str(int(p["random"].call()) % 2), 0, p)
		failed=_failure(p);if not failed.is_empty():return failed
	if result in [3, 10]: _sound(actor, weapon, "Critical0", 0, p)
	failed=_failure(p);if not failed.is_empty():return failed
	if result in [2, 4] and _category(target, p) != 0:
		_sound(actor, weapon, "Parry0", 0, p)
		failed=_failure(p);if not failed.is_empty():return failed
		return {"played": true, "error": ""}
	var armor := ""
	if int(target.get("objectType", 0)) == 5:
		armor = str(p["armorOverride"].call(target))
		if armor.is_empty():
			var sound_type: int = _appearance_sound(target, p)
			failed=_failure(p);if not failed.is_empty():return failed
			var custom: Dictionary = p["string"].call("appearancesndset", sound_type, "Custom")
			failed=_failure(p);if not failed.is_empty():return failed
			if bool(custom.found):
				p["play"].call(actor, str(custom.value), 0)
				return {"played": true, "error": ""}
			armor = str(p["string"].call("appearancesndset", sound_type, "ArmorType").value)
			failed=_failure(p);if not failed.is_empty():return failed
			if armor.is_empty():
				var item: Variant = p["equipped"].call(target, 2)
				var armor_index: int = int(p["armorIndex"].call(item)) if item != null else 0
				failed=_failure(p);if not failed.is_empty():return failed
				armor = str(p["string"].call("defaultacsounds", armor_index, "ArmorType").value)
				failed=_failure(p);if not failed.is_empty():return failed
	elif int(target.get("objectType", 0)) == 10:
		var types: Dictionary = p["doorTypes"].call(target)
		failed=_failure(p);if not failed.is_empty():return failed
		var door_type: int = int(types.doorType)
		var table_name := "genericdoors" if door_type == 0 else "doortypes"
		var type_index: int = int(types.genericType) if door_type == 0 else door_type
		var row: int = int(p["int"].call(table_name, type_index, "SoundAppType").value)
		failed=_failure(p);if not failed.is_empty():return failed
		armor = str(p["string"].call("placeableobjsnds", row, "ArmorType").value)
		failed=_failure(p);if not failed.is_empty():return failed
	elif int(target.get("objectType", 0)) == 9:
		var appearance: int=int(p["appearance"].call(target))
		failed=_failure(p);if not failed.is_empty():return failed
		var row: int = int(p["int"].call("placeables", appearance, "SoundAppType").value)
		failed=_failure(p);if not failed.is_empty():return failed
		armor = str(p["string"].call("placeableobjsnds", row, "ArmorType").value)
		failed=_failure(p);if not failed.is_empty():return failed
	_sound(actor, weapon, armor + str(int(p["random"].call()) % 2), 0, p)
	failed=_failure(p);if not failed.is_empty():return failed
	return {"played": true, "error": ""}

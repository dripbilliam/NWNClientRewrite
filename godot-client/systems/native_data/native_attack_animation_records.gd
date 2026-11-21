extends RefCounted
# Creature attack group projection from network_attack_animation.js.
const OBJECT_INVALID:=0x7f000000
var failure:=""
static func _signed32(value: Variant) -> int:
	var bits:=int(value)&0xffffffff
	return bits-0x100000000 if bits>=0x80000000 else bits

func records(source_id: int,attacks: Variant) -> Array:
	failure=""
	if not attacks is Array or attacks.size()>3:
		failure="Native attack animation group is invalid"
		return []
	if attacks.is_empty():
		return [{"type":0,"sourceId":OBJECT_INVALID,"duration":0,"damage":0,"result":0,"targetId":OBJECT_INVALID,"reactionDelay":0,"reaction":0,"reactionDuration":0,"attackType":0,"ranged":0,"killingBlow":0,"weaponAttackType":0}]
	var result: Array=[]
	for attack in attacks:
		result.append({"type":1,"sourceId":source_id&0xffffffff,"duration":int(attack.field2)&65535,"damage":int(attack.damage)&65535,"result":int(attack.result)&255,"targetId":int(attack.target)&0xffffffff,"reactionDelay":0,"reaction":int(attack.fieldA)&65535,"reactionDuration":int(attack.fieldC)&65535,"attackType":int(attack.field7A)&65535,"ranged":_signed32(attack.field5C),"killingBlow":_signed32(attack.field68),"weaponAttackType":int(attack.field56)&255})
	return result

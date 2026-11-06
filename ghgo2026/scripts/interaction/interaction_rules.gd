class_name InteractionRules
extends RefCounted

enum Realm { ANY, LIVING_ONLY, ASTRAL_ONLY }

static func realm_matches(realm: Realm) -> bool:
	match realm:
		Realm.LIVING_ONLY:
			return not GameState.in_astral
		Realm.ASTRAL_ONLY:
			return GameState.in_astral
	return true

static func get_block_reason(realm: Realm, required_bars: int, energy_cost: float) -> String:
	if not realm_matches(realm):
		if realm == Realm.ASTRAL_ONLY:
			return "Only in the astral plane"
		return "Only in the living world"
	if not GameState.has_unlocked_bars(required_bars):
		return "Requires %d bars" % required_bars
	if not GameState.can_afford(energy_cost):
		return "Not enough energy"
	return ""

static func try_pay(energy_cost: float) -> bool:
	return energy_cost <= 0.0 or GameState.try_spend(energy_cost)

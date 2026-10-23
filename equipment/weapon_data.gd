class_name WeaponData
extends EquipmentData
## Weapon slot — raises damage (PlayerStats.damage()) and picks which of the
## three combat styles orb-hits use.
##
## Only `kind` == SWORD actually has combat behavior wired up right now —
## Arena/Orb still only know the one combo-based hit-an-orb loop. BOW (stack
## "arrow" orbs, then "shoot" orbs release the stacked damage) and STAFF
## (elemental orbs that chain bonus-damage "reactions" when you hit two
## different elements back to back) are designed but not yet built — the
## enum exists now so the data model and shop don't need touching again once
## that combat work starts; a non-sword WeaponData will just behave like a
## sword (damage_bonus applies, no special orb behavior) until then.
enum Kind { SWORD, BOW, STAFF }

@export var kind: Kind = Kind.SWORD
@export var damage_bonus := 0.0

class_name ShipMotion
extends RefCounted
## The gentle rocking of the ship. Everything that stands on the deck is drawn through the same
## transform so it all moves together: a small roll about a pivot plus an up and down bob.

const ROLL_AMOUNT: float = 0.85  # 1.0 is a lively sway; lower to calm the sea


static func roll(t: float) -> float:
	return (sin(t * 1.15) * 0.02 + sin(t * 0.63 + 1.3) * 0.008) * ROLL_AMOUNT


static func bob(t: float) -> float:
	return (sin(t * 1.6 + 0.6) * 2.5 + sin(t * 0.9) * 1.5) * ROLL_AMOUNT


## Transform that rotates by the current roll about pivot (in the item's local pixels).
static func transform(pivot: Vector2, t: float) -> Transform2D:
	return Transform2D(roll(t), pivot + Vector2(0.0, bob(t))) * Transform2D(0.0, -pivot)


## Extra lean of a person standing on the deck: against the roll and a beat behind it, as if
## balancing. About 3.8 times the deck's roll, so it is clearly visible.
static func lean(t: float) -> float:
	return -roll(t - 0.35) * 3.8


## Sideways roll of loose cannonballs on the planks, in pixels, trailing the deck's roll.
static func slide(t: float) -> float:
	return sin(t * 1.15 - 0.5) * 7.0 * ROLL_AMOUNT

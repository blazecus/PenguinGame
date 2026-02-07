extends Node

# didn't want to use globals but i split throwing physics in two files and they use some weird logic
# to match trajectory simulation to actual throwing trajectories
const THROW_STRENGTH_MODIFIER = 5.0
const THROW_MAX_PULL_LENGTH = 150

# in case i need it
func layers_to_mask(layers: Array) -> int:
	var mask = 0
	for layer in layers:
		mask |= 1 << (layer - 1)
	return mask

func _ready():
	randomize()

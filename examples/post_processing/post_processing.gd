extends Node

@onready var compute_flow: ComputeFlow = $ComputeFlow

var time=0.0

func _process(delta: float) -> void:
	time += delta
	compute_flow.set_push_constant("time",time)
	compute_flow.run()

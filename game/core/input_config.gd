class_name InputConfig
extends RefCounted
## Captain-approved emulator settings, not medical or hardware parameters.

enum RecoveryPolicy { NEUTRAL_AND_RESUME, NEUTRAL_ONLY }

var on_a: float
var off_a: float
var on_b: float
var off_b: float
var timeout_ms: int
var recovery_policy: RecoveryPolicy
var rest_pauses: bool
var heartbeat_ms: int


## Explicit MVP profile; channel thresholds remain independently configurable.
static func emulator_profile() -> InputConfig:
	return InputConfig.new(0.55, 0.40, 0.55, 0.40, 250,
		RecoveryPolicy.NEUTRAL_AND_RESUME, true, 50)


## Hysteresis widths are on_a-off_a and on_b-off_b. 250 ms comes from contracts.
func _init(
	p_on_a: float,
	p_off_a: float,
	p_on_b: float,
	p_off_b: float,
	p_timeout_ms: int = 250,
	p_recovery_policy: RecoveryPolicy = RecoveryPolicy.NEUTRAL_AND_RESUME,
	p_rest_pauses: bool = true,
	p_heartbeat_ms: int = 50
) -> void:
	on_a = p_on_a
	off_a = p_off_a
	on_b = p_on_b
	off_b = p_off_b
	timeout_ms = p_timeout_ms
	recovery_policy = p_recovery_policy
	rest_pauses = p_rest_pauses
	heartbeat_ms = p_heartbeat_ms


## Returns a reason rather than asserting or crashing the host scene.
func validation_error() -> StringName:
	if not _valid_pair(on_a, off_a) or not _valid_pair(on_b, off_b):
		return &"invalid_thresholds"
	if timeout_ms <= 0:
		return &"invalid_timeout"
	# Legacy constructor options cannot bypass the captain-approved safety policy.
	if recovery_policy != RecoveryPolicy.NEUTRAL_AND_RESUME:
		return &"explicit_resume_required_by_policy"
	if not rest_pauses:
		return &"rest_pause_required_by_policy"
	if heartbeat_ms <= 0 or heartbeat_ms >= timeout_ms:
		return &"invalid_heartbeat"
	return &""


func _valid_pair(on: float, off: float) -> bool:
	return is_finite(on) and is_finite(off) and 0.0 <= off and off < on and on < 1.0

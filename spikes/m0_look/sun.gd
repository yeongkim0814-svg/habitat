extends RefCounted
## D43: the sun circles the habitat axis (Z) outside the cylinder; its light enters along the axis at angle ALPHA_DEG.
## A floor point is brightest when the sun azimuth is on the opposite side, so the Safe and Danger zones (opposite half rings)
## are in opposite phase. Pure functions, no nodes: testable headless.
const ALPHA_DEG := 35.0
const SAFE_FLOOR_ANGLE := -PI / 2.0 # floor angle theta of the safe zone center (point = R * (cos, sin))
const DANGER_FLOOR_ANGLE := PI / 2.0

static func azimuth(hour: float) -> float:
	# Noon (12 h): the sun is on the +Y side, i.e. opposite the safe zone center floor.
	return PI / 2.0 + (hour - 12.0) / 24.0 * TAU

static func to_sun(hour: float, alpha_deg: float = ALPHA_DEG) -> Vector3:
	var a := deg_to_rad(alpha_deg)
	var phi := azimuth(hour)
	return Vector3(sin(a) * cos(phi), sin(a) * sin(phi), cos(a))

static func elevation_deg(hour: float, floor_angle: float, alpha_deg: float = ALPHA_DEG) -> float:
	var inward := Vector3(-cos(floor_angle), -sin(floor_angle), 0.0)
	return rad_to_deg(asin(clampf(inward.dot(to_sun(hour, alpha_deg)), -1.0, 1.0)))

static func light_energy(elev_deg: float) -> float:
	return 0.8 * smoothstep(-1.0, 8.0, elev_deg)

static func light_color(elev_deg: float) -> Color:
	# Warm and low at sunrise/sunset, near white high in the sky.
	return Color(1.0, 0.58, 0.34).lerp(Color(1.0, 0.97, 0.92), smoothstep(0.0, 30.0, elev_deg))

static func sky_color(elev_deg: float) -> Color:
	var dusk := Color(0.86, 0.52, 0.42).lerp(Color(0.52, 0.70, 0.95), smoothstep(2.0, 28.0, elev_deg))
	return Color(0.03, 0.04, 0.09).lerp(dusk, smoothstep(-8.0, 2.0, elev_deg))

static func ambient_color(elev_deg: float) -> Color:
	# Cool ambient makes the shade bluish in daylight (painterly look); night is dark blue.
	return Color(0.12, 0.14, 0.24).lerp(Color(0.62, 0.72, 0.95), smoothstep(-6.0, 20.0, elev_deg))

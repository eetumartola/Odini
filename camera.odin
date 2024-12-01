package main

import rl "vendor:raylib"
import "core:math"
import "core:math/rand"

camera :: struct {
	center         : rl.Vector3,
	pixel00_loc    : rl.Vector3,
	pixel_delta_u  : rl.Vector3,
	pixel_delta_v  : rl.Vector3,
	u, v, w        : rl.Vector3, // camera frame basis vectors
	defocus_radius : f32,
	defocus_disk_u : rl.Vector3,
	defocus_disk_v : rl.Vector3,
}

package main

import rl "vendor:raylib"
import "core:math"
import "core:math/rand"

vec3_random :: proc() -> rl.Vector3 {
	return rl.Vector3{rand.float32(), rand.float32(), rand.float32()}
}
vec3_random_range :: proc(min : f32, max : f32) -> rl.Vector3 {
	return rl.Vector3{rand.float32_uniform(min,max), rand.float32_uniform(min,max), rand.float32_uniform(min,max)}
}
vec3_near_zero :: proc(e : rl.Vector3) -> bool {
    // Return true if the vector is close to zero in all dimensions.
    s : f32 = 1e-8;
    return (abs(e[0]) < s) && (abs(e[1]) < s) && (abs(e[2]) < s)
}

random_unit_vector :: proc() -> rl.Vector3 {
    for {
        p : rl.Vector3 = vec3_random_range(-1.0, 1.0)
        lensq := rl.Vector3LengthSqr(p)
        if (1e-13 < lensq && lensq <= 1.0) {
            return p / math.sqrt_f32(lensq)
        }
    }
}
random_in_unit_disk :: proc() -> rl.Vector3 {
    for {
        p : rl.Vector3 = {rand.float32_uniform(-1,1), rand.float32_uniform(-1,1), 0.0}
        if (rl.Vector3LengthSqr(p) < 1.0) {
            return p
        }
    }
}
random_on_hemisphere :: proc(normal : rl.Vector3) -> rl.Vector3 {
    on_unit_sphere := random_unit_vector()
    if ( rl.Vector3DotProduct(on_unit_sphere, normal) > 0.0) {// In the same hemisphere as the normal
        return on_unit_sphere
    }
    else {
        return -on_unit_sphere
    }
}

linear_to_gamma :: proc(lin : f32) -> f32 {
	if (lin > 0.0) {
		return math.sqrt_f32(lin)
	}
	return 0.0
}
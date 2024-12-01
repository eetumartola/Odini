package main

import rl "vendor:raylib"
import "core:math"
import "core:math/rand"


material :: struct {
	scatter : proc( r_in : ray, rec : hit_record) -> (attenuation : rl.Vector3, scattered : ray),
	albedo : rl.Vector3,
	fuzz : f32,
	ior : f32,
}
vec3_reflect :: proc(v : rl.Vector3, n : rl.Vector3) -> rl.Vector3 {
    return v - 2.0 * rl.Vector3DotProduct(v,n) * n
}
vec3_refract :: proc(uv : rl.Vector3, n : rl.Vector3, etai_over_etat : f32) -> rl.Vector3 {
    cos_theta : f32 = min(rl.Vector3DotProduct(-uv, n), 1.0)
    r_out_perp : rl.Vector3 =  etai_over_etat * (uv + cos_theta*n)
    r_out_parallel : rl.Vector3 = -math.sqrt_f32(abs(1.0 - rl.Vector3LengthSqr(r_out_perp))) * n
    return r_out_perp + r_out_parallel;
}
vec3_reflectance :: proc(cosine : f32, ior : f32) -> f32 {
    // Use Schlick's approximation for reflectance.
    r0 : f32 = (1 - ior) / (1 + ior)
    r0 = r0 * r0
    return r0 + (1 - r0) * math.pow_f32((1 - cosine), 5)
}

scatter_lambertian :: proc( r_in : ray, rec : hit_record) -> (attenuation : rl.Vector3, scattered : ray) {
	//fmt.println("scatter_lambertian")
 scatter_direction : rl.Vector3 = rec.normal + random_unit_vector()
 if (vec3_near_zero(scatter_direction)) {
	 scatter_direction = rec.normal
 }
 scattered = ray{rec.p, scatter_direction}
 attenuation = rec.mat.albedo
 return attenuation, scattered
}

scatter_metal :: proc( r_in : ray, rec : hit_record) -> (attenuation : rl.Vector3, scattered : ray) {
	fuzz : f32 = rec.mat.fuzz
 reflected : rl.Vector3 = vec3_reflect(r_in.dir, rec.normal)
 reflected = rl.Vector3Normalize(reflected) + (fuzz * random_unit_vector())
 scattered = ray{rec.p, reflected}
 attenuation = rec.mat.albedo
 return attenuation, scattered
}

scatter_glass :: proc(r_in : ray, rec : hit_record) -> (attenuation : rl.Vector3, scattered : ray) {
 attenuation = rec.mat.albedo;
 ri : f32 = rec.front_face ? (1.0 / rec.mat.ior) : rec.mat.ior
 unit_direction : rl.Vector3 = rl.Vector3Normalize(r_in.dir)

 cos_theta : f32 = min(rl.Vector3DotProduct(-unit_direction, rec.normal), 1.0)
 sin_theta : f32 = math.sqrt_f32(1.0 - cos_theta*cos_theta)

 cannot_refract : bool = ri * sin_theta > 1.0
 direction : rl.Vector3

 if (cannot_refract || vec3_reflectance(cos_theta, ri) > rand.float32()) {
	 direction = vec3_reflect(unit_direction, rec.normal)
 }
 else {
	 direction = vec3_refract(unit_direction, rec.normal, ri)
 }
 scattered = ray{rec.p, direction}
 return attenuation, scattered
}
package main

import rl "vendor:raylib"
import "core:math"
import "core:math/rand"


sphere :: struct {
	center : ray,
	radius : f32,
	mat : material,
    bbox : aabb,
}

hit_sphere :: proc( s: sphere, r: ray, ray_t : interval, rec : ^hit_record ) -> bool {
    current_center : rl.Vector3 = ray_at(s.center, r.time)
    oc : rl.Vector3 = current_center - r.orig
    a  : f32 = rl.Vector3LengthSqr(r.dir)
    h  : f32 = rl.Vector3DotProduct(r.dir, oc)
    c  : f32 = rl.Vector3LengthSqr(oc) - s.radius * s.radius
    discriminant : f32 = h * h - a * c

    if (discriminant < 0.0) {
        return false
    }
    sqrtd : f32 = math.sqrt_f32(discriminant)

    // Find the nearest root that lies in the acceptable range.
    root : f32 = (h - sqrtd) / a;
    if (!interval_surrounds(ray_t, root)) {
        root = (h + sqrtd) / a;
        if (!interval_surrounds(ray_t, root)) {
            return false
        }
    }

    rec.t = root
    rec.p = ray_at(r, rec.t)
    outward_normal : rl.Vector3 = (rec.p - current_center) / s.radius
    rec.front_face = rl.Vector3DotProduct(r.dir, outward_normal) < 0.0
    rec.normal = rec.front_face ? outward_normal : -outward_normal
    rec.u, rec.v = get_sphere_uv(outward_normal)
    rec.mat = s.mat

    return true
}

bbox_sphere :: proc(s : sphere) -> aabb {
	rvec : rl.Vector3 = {s.radius, s.radius, s.radius, }
	bbox1 : aabb = aabb_create_2points(ray_at(s.center, 0) - rvec, ray_at(s.center, 0) + rvec)
	bbox2 : aabb = aabb_create_2points(ray_at(s.center, 1) - rvec, ray_at(s.center, 1) + rvec)
	bbox: aabb = aabb_create_2boxes(bbox1, bbox2)
	return bbox
}

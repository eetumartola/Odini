package main

import rl "vendor:raylib"
import "core:math"
import "core:math/rand"

interval :: struct {
	min : f32,
	max : f32,
}

aabb :: struct {
    x : interval,
    y : interval,
    z : interval,
}

// a does not need to be smaller than b
aabb_create_2points :: proc(a : rl.Vector3, b : rl.Vector3) -> aabb {
    x : interval = (a[0] <= b[0]) ? interval{a[0], b[0]} : interval{b[0], a[0]}
    y : interval = (a[1] <= b[1]) ? interval{a[1], b[1]} : interval{b[1], a[1]}
    z : interval = (a[2] <= b[2]) ? interval{a[2], b[2]} : interval{b[2], a[2]}
    return aabb{x, y, z}
}

aabb_create_2boxes :: proc(box0 : aabb, box1 : aabb) -> aabb {
    x : interval = interval_join(box0.x, box1.x)
    y : interval = interval_join(box0.y, box1.y)
    z : interval = interval_join(box0.z, box1.z)
    return aabb{x, y, z}
}

interval_join :: proc(a  : interval, b : interval) -> interval {
    // Create the interval tightly enclosing the two input intervals.
    min : f32 = a.min <= b.min ? a.min : b.min
    max : f32 = a.max >= b.max ? a.max : b.max
    return interval{min, max}
}

axis_interval :: proc(bbox : aabb, n : i32) -> interval {
    if (n == 1) do return bbox.y
    if (n == 2) do return bbox.z
    return bbox.x
}

//should we return ray_t as well? should we carry hit_record through this?
hit_aabb :: proc(bbox : aabb, r : ray, ray_t : ^interval) -> bool {
    ray_orig : rl.Vector3 = r.orig
    ray_dir  : rl.Vector3 = r.dir

    for axis : i32 = 0; axis < 3; axis += 1 {
        ax : interval = axis_interval(bbox, axis)
        adinv : f32 = 1.0 / ray_dir[axis]

        t0 := (ax.min - ray_orig[axis]) * adinv
        t1 := (ax.max - ray_orig[axis]) * adinv

        if (t0 < t1) {
            if (t0 > ray_t.min) do ray_t.min = t0
            if (t1 < ray_t.max) do ray_t.max = t1
        } else {
            if (t1 > ray_t.min) do ray_t.min = t1
            if (t0 < ray_t.max) do ray_t.max = t0
        }

        if (ray_t.max <= ray_t.min) do return false
    }
    return true
}

interval_size :: proc(i : interval) -> f32 {
	return i.max - i.min
}

interval_contains :: proc(i : interval, x: f32) -> bool {
	return i.min <= x && x <= i.max
}

interval_surrounds :: proc(i : interval, x: f32) -> bool {
	return i.min < x && x < i.max
}

interval_expand :: proc(i : interval, delta : f32) -> interval {
    padding : f32 = delta / 2.0;
    return interval{i.min - padding, i.max + padding};
}
package main

import rl "vendor:raylib"
import "core:math"
import "core:math/rand"

bvh_node :: struct {
	left  : ^hittable,
	right : ^hittable,
	bbox  : aabb
}

bvh_hit :: proc(bvh : bvh_node, r : ray, ray_t : ^interval, rec : hit_record) -> bool {
	if (! hit_aabb(bvh.bbox, r, ray_t))  do return false

	hit_left  : bool = hit_aabb(bvh.left.bbox, r, ray_t);
	hit_right : bool = hit_aabb(bvh.right.bbox, r, &interval{ray_t.min, hit_left ? rec.t : ray_t.max});

	return hit_left || hit_right;
}

/*
bvh_build :: proc(bvh : ^bvh_node, world : hittable_list, start : i32, end : i32) {
	axis : i32 = rand.int31()%3

	comparator := (axis == 0) ? box_x_compare : (axis == 1) ? box_y_compare : box_z_compare
	object_span : i32 = end - start

	if (object_span == 1) {
		bvh.left =  world.objects[start]
		bvh.right = world.objects[start]
	} else if (object_span == 2) {
		left = world[start]
		right = world[start + 1]
	} else {
		//sort(std::begin(objects) + start, std::begin(objects) + end, comparator);

		mid : i32 = start + object_span/2
		bvh.left  := bvh_build(&bvh, world, start, mid)
		bvh.right := bvh_build(&bvh, world, mid, end)
	}

	bvh.bbox = aabb_create_2boxes(bvh.left.bbox, bvh.right.bbox)
}
*/
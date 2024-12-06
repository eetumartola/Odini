package main

import rl "vendor:raylib"
import "core:math"
import "core:math/rand"

setup_world :: proc() -> hittable_list {
    
    // TEXTURES
    tex_checkerboard : texture = {
        func = texture_checkerboard,
        albedo = {0.1,0.1,0.1},
        albedo_secondary = {1.0,1.0,1.0},
        scale = 0.3,
    }
    tex_image : texture = {
        func = texture_image,
        albedo = {0.1,0.1,0.1},
        albedo_secondary = {1.0,1.0,1.0},
        scale = 0.3,
        image_name = "world",
    }
    tex_solid : texture = {
        func = texture_solid,
        albedo = {1.0,1.0,1.0},
        albedo_secondary = {1.0,1.0,1.0},
        scale = 1.0,
    }

    // MATERIALS
	clay : material = {
		scatter = scatter_lambertian,
		albedo = {1.0, 1.0, 1.0},
		fuzz = 0.1,
		ior = 1.0,
        tex = tex_image,
	}
	ground : material = {
		scatter = scatter_lambertian,
		albedo = {0.65, 0.65, 0.65},
		fuzz = 0.1,
		ior = 1.0,
        tex = tex_checkerboard,
	}
	metal : material = {
		scatter = scatter_metal,
		albedo = {0.85, 0.85, 0.45},
		fuzz = 0.2,
		ior = 1.0,
        tex = tex_solid,
	}
	glass : material = {
		scatter = scatter_glass,
		albedo = {1, 1, 1},
		fuzz = 0.1,
		ior = 1.5,
        tex = tex_solid,
	}
	glass_air : material = {
		scatter = scatter_glass,
		albedo = {1, 1, 1},
		fuzz = 0.1,
		ior = .67,
        tex = tex_solid,
	}

	sphere1 : hittable = {
		name = "sphere",
		data = sphere{
            center = {{0.0, 0.0, -1.2}, {0.0, 0.0, 0.0}, 0.0},
            radius = 0.5,
            mat = clay},
		hit_func = hit_sphere,
		bbox_func = bbox_sphere,
	}
	sphere_glass_outer : hittable = {
		name = "sphere_go",
		data = sphere{
            center = {{-1.0, 0.0, -1.0}, {0.0, 0.0, 0.0}, 0.0},
            radius = 0.5,
            mat = glass},
		hit_func = hit_sphere,
		bbox_func = bbox_sphere,
	}
	sphere_glass_inner : hittable = {
		name = "sphere_gi",
		data = sphere{
            center = {{-1.0, 0.0, -1.0}, {0.0, 0.0, 0.0}, 0.0},
            radius = 0.4,
            mat = glass_air},
		hit_func = hit_sphere,
		bbox_func = bbox_sphere,
	}
	sphere_metal : hittable = {
		name = "sphere",
		data = sphere{
            center = {{1.0, 0.0, -1.0}, {0.1, 0.0, 0.2}, 0.0},
            radius = 0.5,
            mat =  metal},
		hit_func = hit_sphere,
		bbox_func = bbox_sphere,
	}
	sphere_big : hittable = {
		name = "sphere_big",
		data = sphere{
            center = {{0.0, -100.5, -1.0}, {0.0, 0.0, 0.0}, 0.0},
            radius = 100.0,
            mat = ground},
		hit_func = hit_sphere,
		bbox_func = bbox_sphere,
	}

	world : hittable_list

	world_add(&world, &sphere1)
	world_add(&world, &sphere_glass_outer)
	world_add(&world, &sphere_glass_inner)
	world_add(&world, &sphere_metal)
	world_add(&world, &sphere_big)

    return world
}

world_add :: proc(world : ^hittable_list, o : ^hittable) {
	append(&world.objects, o^)
	o^.bbox = o^.bbox_func(o^.data)
}

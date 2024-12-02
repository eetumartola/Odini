package main

import "core:fmt"
import "core:os"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

WINDOW_WIDTH  :: 1024
WINDOW_HEIGHT :: 576

g_debug_line : i32 = 0

ray :: struct {
	orig : rl.Vector3,
	dir  : rl.Vector3,
}

ray_at :: proc(ray: ray, t : f32) -> rl.Vector3 {
	return ray.orig + ray.dir * t
}

hit_record :: struct {
	p : rl.Vector3,
	normal  : rl.Vector3,
	t : f32,
	front_face : bool,
	mat : material,
    u : f32,
    v : f32,
}

sphere :: struct {
	center : rl.Vector3,
	radius : f32,
	mat : material,
}

hittable :: struct {
	name : string,
	data : sphere,
	hit_func : proc( s: sphere, r: ray, ray_t : interval, rec : ^hit_record ) -> bool
}

interval :: struct {
	min : f32,
	max : f32,
}

texture_lib := make(map[string]rl.Image)

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Odini")
	defer rl.CloseWindow()
	render_tex : rl.Texture

    texture_lib_load()

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
		fuzz = 0.4,
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
		data = sphere{{0.0, 0.0, -1.2}, 0.5, clay},
		hit_func = sphere_hit,
	}
	sphere_glass_outer : hittable = {
		name = "sphere_go",
		data = sphere{{-1.0, 0.0, -1.0}, 0.5, glass},
		hit_func = sphere_hit,
	}
	sphere_glass_inner : hittable = {
		name = "sphere_gi",
		data = sphere{{-1.0, 0.0, -1.0}, 0.4, glass_air},
		hit_func = sphere_hit,
	}
	sphere_metal : hittable = {
		name = "sphere",
		data = sphere{{1.0, 0.0, -1.0}, 0.5, metal},
		hit_func = sphere_hit,
	}
	sphere_big : hittable = {
		name = "sphere_big",
		data = sphere{{0.0, -100.5, -1.0}, 100.0, ground},
		hit_func = sphere_hit,
	}

	world : [dynamic]hittable
	append(&world, sphere1)
	append(&world, sphere_glass_outer)
	append(&world, sphere_glass_inner)
	append(&world, sphere_metal)
	append(&world, sphere_big)

	render_tex = render(world)

	rl.SetTargetFPS(60)      
	for !rl.WindowShouldClose() { // Detect window close button or ESC key
		draw(render_tex)
	}
}

hit_world :: proc(world: [dynamic]hittable, r : ray, ray_t : interval, rec : ^hit_record) -> bool {
    temp_rec : hit_record;
    hit_anything : bool = false;
    closest_so_far : f32 = ray_t.max;

    for h in world {
        if (h.hit_func(h.data, r, interval{ray_t.min, closest_so_far}, &temp_rec)) {
            hit_anything = true;
            closest_so_far = temp_rec.t;
            rec.p = temp_rec.p;
            rec.normal = temp_rec.normal;
            rec.t = temp_rec.t;
            rec.front_face = temp_rec.front_face; // is there a better way?
            rec.mat = temp_rec.mat
            rec.u = temp_rec.u
            rec.v = temp_rec.v
        }
    }
    return hit_anything;
}

ray_color :: proc(r : ray, depth : i32, world : [dynamic]hittable) -> rl.Vector3 {
	if (depth <= 0) {
		return {0,0,0}
	}
	rec : hit_record
	if (hit_world(world, r, interval{0.0002, 10000000.0}, &rec)) {
	   	//fmt.println("hit_world")
		scattered : ray
		attenuation : rl.Vector3
		mat_this := rec.mat
		attenuation, scattered = mat_this.scatter(r, rec)
	   	//fmt.println("hit_world scattered")

		if (true) {
            return attenuation * ray_color(scattered, depth - 1, world)
        }
        return rl.Vector3{0,0,0}
	}

    unit_direction : rl.Vector3 = rl.Vector3Normalize(r.dir)
    a : f32 = f32(0.5) * (unit_direction.y + f32(1.0))
    col : rl.Vector3 = rl.Vector3Lerp({1,1,1},{0.2,0.3,1.0},a)
	return col
}

sphere_hit :: proc( s: sphere, r: ray, ray_t : interval, rec : ^hit_record ) -> bool {
    oc : rl.Vector3 = s.center - r.orig
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
    outward_normal : rl.Vector3 = (rec.p - s.center) / s.radius
    rec.front_face = rl.Vector3DotProduct(r.dir, outward_normal) < 0.0
    rec.normal = rec.front_face ? outward_normal : -outward_normal
    rec.u, rec.v = get_sphere_uv(outward_normal)
    rec.mat = s.mat

    return true
}

render :: proc(world : [dynamic]hittable) -> rl.Texture {
	rl.BeginDrawing()
	defer rl.EndDrawing()
    g_debug_line = 0 // keeping count of how many debug lines have been drawn onto the screen

    img : rl.Image = rl.GenImageColor(WINDOW_WIDTH, WINDOW_HEIGHT, rl.BLACK)
   
    cam : camera
    // Camera
    max_depth           : i32 = 9
    samples_per_pixel   : i32 = 12
    pixel_samples_scale : f32 = 1.0 / f32(samples_per_pixel)
    vfov				: f32 = 30.0
    theta   			: f32 = math.to_radians_f32(vfov)
    h 					: f32 = math.tan_f32(theta / 2.0)
    lookfrom            : rl.Vector3 = {-2.0, 2.0, 1.0}  // Point camera is looking from
    lookat              : rl.Vector3 = {0.0, 0.0, -1.0}  // Point camera is looking at
    vup                 : rl.Vector3 = {0.0, 1.0, 0.0}   // Camera-relative "up" direction
    defocus_angle       : f32 = 3.0;  // Variation angle of rays through each pixel
    focus_dist          : f32 = 3.2; // Distance from camera lookfrom point to plane of perfect focus

    cam.center          = lookfrom

    viewport_height     : f32 = 2.0 * h * focus_dist
    viewport_width	    : f32 = viewport_height * f32(WINDOW_WIDTH) / f32(WINDOW_HEIGHT)

    // Calculate the u,v,w unit basis vectors for the camera coordinate frame.
    w : rl.Vector3 = rl.Vector3Normalize(lookfrom - lookat)
    u : rl.Vector3 = rl.Vector3Normalize(rl.Vector3CrossProduct(vup, w))
    v : rl.Vector3 = rl.Vector3CrossProduct(w, u)

    // Calculate the vectors across the horizontal and down the vertical viewport edges.
    viewport_u : rl.Vector3 = viewport_width * u
    viewport_v : rl.Vector3 = viewport_height * -v

    // Calculate the horizontal and vertical delta vectors from pixel to pixel.
    cam.pixel_delta_u  = viewport_u / WINDOW_WIDTH
    cam.pixel_delta_v  = viewport_v / WINDOW_HEIGHT

    // Calculate the location of the upper left pixel.
    viewport_upper_left : rl.Vector3 = cam.center - (w * focus_dist) - viewport_u/2.0 - viewport_v/2.0
    cam.pixel00_loc = viewport_upper_left + 0.5 * (cam.pixel_delta_u + cam.pixel_delta_v)

    // Calculate the camera defocus disk basis vectors.
    cam.defocus_radius = focus_dist * math.tan_f32(math.to_radians(defocus_angle / 2.0))
    cam.defocus_disk_u = u * cam.defocus_radius
    cam.defocus_disk_v = v * cam.defocus_radius

    render_tex : rl.Texture = rl.LoadTextureFromImage(img)
    for h : i32 = 0; h < WINDOW_HEIGHT; h += 1 {
        for w : i32 = 0; w < WINDOW_WIDTH; w += 1 {
        	pixel_color : rl.Vector3 = {0,0,0}
        	for sample : i32 = 0; sample < samples_per_pixel; sample += 1 {
        		r : ray = get_ray(cam, w, h)
        		pixel_color += ray_color(r, max_depth, world) * pixel_samples_scale
        	}
        	rl_color : rl.Color = rl.ColorFromNormalized({linear_to_gamma(pixel_color.x), linear_to_gamma(pixel_color.y), linear_to_gamma(pixel_color.z), 1.0})
			rl.ImageDrawPixel(&img, w, h, rl_color)
        }
		//fmt.print(" ", h)
        rl.UpdateTexture(render_tex, img.data)
        draw(render_tex)
        if rl.WindowShouldClose() do os.exit(0)
    }
    return render_tex
}

get_ray :: proc(cam : camera, w : i32, h : i32) -> ray {
    // Construct a camera ray originating from the defocus disk and directed at a randomly
    // sampled point around the pixel location i, j.	
    offset : rl.Vector3 = sample_square()
    pixel_sample : rl.Vector3 = cam.pixel00_loc + ((f32(w) + offset.x) * cam.pixel_delta_u) + ((f32(h) + offset.y) * cam.pixel_delta_v)

    ray_origin     : rl.Vector3 = cam.defocus_radius <= 0 ? cam.center : defocus_disk_sample(cam)
    ray_direction  : rl.Vector3 = pixel_sample - ray_origin

    return ray{ray_origin, ray_direction}
}

sample_square :: proc() -> rl.Vector3 {
    // Returns the vector to a random point in the [-.5,-.5]-[+.5,+.5] unit square.
    return rl.Vector3{rand.float32() - 0.5, rand.float32() - 0.5, 0}
}
defocus_disk_sample :: proc(cam : camera) -> rl.Vector3 {
    // Returns a random point in the camera defocus disk.
    p : rl.Vector3 = random_in_unit_disk()
    return cam.center + (p[0] * cam.defocus_disk_u) + (p[1] * cam.defocus_disk_v)
}

draw :: proc(tex : rl.Texture) {
	rl.BeginDrawing()
	defer rl.EndDrawing()
	//rl.ClearBackground(rl.RAYWHITE)
	//rl.DrawText("DEBUG", 300, 10, 10, rl.GRAY)
	rl.DrawTexture(tex, 0, 0, rl.WHITE)
}

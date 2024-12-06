package main

import "core:fmt"
import "core:os"
import "core:math"
import "core:math/rand"

import "core:sync"
import "core:thread"
import "core:mem"
import "core:mem/virtual"

import rl "vendor:raylib"

WINDOW_WIDTH  :: 1024
WINDOW_HEIGHT :: 576

g_debug_line : i32 = 0

ray :: struct {
	orig : rl.Vector3,
	dir  : rl.Vector3,
    time : f32,
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

hittable :: struct {
	name : string,
	data : sphere,
	hit_func : proc( s: sphere, r: ray, ray_t : interval, rec : ^hit_record ) -> bool,
    bbox_func : proc(s : sphere),
}

hittable_list :: struct {
    objects : [dynamic]hittable,
    bbox : aabb,
}

threadinfo :: struct  {
    numthreads : int,
    world : hittable_list,
    image : ^rl.Image,
    texture : ^rl.Texture,
}

worker :: proc (t: thread.Task) {
    info := cast(^threadinfo)(t.data)
    chunk := t.user_index
    n_chunks := info.numthreads
    chunksize := WINDOW_HEIGHT / n_chunks
    firstrow : i32 = i32(chunk * chunksize)
    lastrow : i32 = i32((chunk + 1) * chunksize)
    render(info.world, info.image, firstrow, lastrow)
    //rl.UpdateTexture(info.texture^, info.image^.data)
    //fmt.printf("working on thread %d of %d \n", t.user_index, info.numthreads)
    //fmt.printf("firstrow %d lastrow %d \n", firstrow, lastrow)
}

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Odini")
	defer rl.CloseWindow()
    img : rl.Image = rl.GenImageColor(WINDOW_WIDTH, WINDOW_HEIGHT, rl.BLACK)
	render_tex : rl.Texture  = rl.LoadTextureFromImage(img)

    texture_lib_load()
    world := setup_world()

    tdata : threadinfo
    tdata.numthreads = 32
    tdata.world = world
    tdata.image = &img
    tdata.texture = &render_tex

    // THREADING
    threadPool :thread.Pool
    thread.pool_init(&threadPool, context.allocator, tdata.numthreads)
    thread.pool_start(&threadPool)
    defer thread.pool_destroy(&threadPool)

    client_arena :virtual.Arena
    arena_allocator_error := virtual.arena_init_growing(&client_arena, 1 * mem.Byte)
    client_allocator := virtual.arena_allocator(&client_arena)
    for i := 0; i < tdata.numthreads; i += 1 {
        thread.pool_add_task(&threadPool, client_allocator, worker, &tdata, i)
    }
    thread.pool_finish(&threadPool)
    /////////
    
 	//render(world, &img)
    rl.UpdateTexture(render_tex, img.data)

	rl.SetTargetFPS(60)      
	for !rl.WindowShouldClose() { // Detect window close button or ESC key
		draw(render_tex)
	}
}

hit_world :: proc(world: hittable_list, r : ray, ray_t : interval, rec : ^hit_record) -> bool {
    temp_rec : hit_record;
    hit_anything : bool = false;
    closest_so_far : f32 = ray_t.max;

    for h in world.objects {
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

ray_color :: proc(r : ray, depth : i32, world : hittable_list) -> rl.Vector3 {
	if (depth <= 0) {
		return {0,0,0}
	}
	rec : hit_record
	if (hit_world(world, r, interval{0.0002, 10000000.0}, &rec)) {
		scattered : ray
		attenuation : rl.Vector3
		mat_this := rec.mat
		attenuation, scattered = mat_this.scatter(r, rec)

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

render :: proc(world : hittable_list, img : ^rl.Image, firstrow : i32 = 0, lastrow: i32 = WINDOW_HEIGHT ) {
	rl.BeginDrawing()
	defer rl.EndDrawing()
    g_debug_line = 0 // keeping count of how many debug lines have been drawn onto the screen

   
    cam : camera
    // Camera
    max_depth           : i32 = 9
    samples_per_pixel   : i32 = 32
    pixel_samples_scale : f32 = 1.0 / f32(samples_per_pixel)
    vfov				: f32 = 20.0
    theta   			: f32 = math.to_radians_f32(vfov)
    h 					: f32 = math.tan_f32(theta / 2.0)
    lookfrom            : rl.Vector3 = {-2.0, 2.0, 1.0}  // Point camera is looking from
    lookat              : rl.Vector3 = {0.0, 0.0, -1.0}  // Point camera is looking at
    vup                 : rl.Vector3 = {0.0, 1.0, 0.0}   // Camera-relative "up" direction
    defocus_angle       : f32 = 1.0;  // Variation angle of rays through each pixel
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

    //render_tex : rl.Texture = rl.LoadTextureFromImage(img)
    for h : i32 = firstrow; h < lastrow; h += 1 {
        for w : i32 = 0; w < WINDOW_WIDTH; w += 1 {
        	pixel_color : rl.Vector3 = {0,0,0}
        	for sample : i32 = 0; sample < samples_per_pixel; sample += 1 {
        		r : ray = get_ray(cam, w, h)
        		pixel_color += ray_color(r, max_depth, world) * pixel_samples_scale
        	}
        	rl_color : rl.Color = rl.ColorFromNormalized({linear_to_gamma(pixel_color.x), linear_to_gamma(pixel_color.y), linear_to_gamma(pixel_color.z), 1.0})
			rl.ImageDrawPixel(img, w, h, rl_color)
        }
		//fmt.print(" ", h)
        //rl.UpdateTexture(render_tex, img.data)
        //draw(render_tex)
        if rl.WindowShouldClose() do os.exit(0)
    }
    //return render_tex
}

get_ray :: proc(cam : camera, w : i32, h : i32) -> ray {
    // Construct a camera ray originating from the defocus disk and directed at a randomly
    // sampled point around the pixel location i, j.	
    offset : rl.Vector3 = sample_square()
    pixel_sample : rl.Vector3 = cam.pixel00_loc + ((f32(w) + offset.x) * cam.pixel_delta_u) + ((f32(h) + offset.y) * cam.pixel_delta_v)

    ray_origin     : rl.Vector3 = cam.defocus_radius <= 0 ? cam.center : defocus_disk_sample(cam)
    ray_direction  : rl.Vector3 = pixel_sample - ray_origin
    ray_time       :f32 = rand.float32()


    return ray{ray_origin, ray_direction, ray_time}
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

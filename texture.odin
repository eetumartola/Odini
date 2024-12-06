package main

import rl "vendor:raylib"
import "core:math"
import "core:fmt"
import "core:os"
import "core:math/rand"

texture :: struct {
	func : proc(tex : texture, u : f32, v : f32, p : rl.Vector3) -> rl.Vector3,
	albedo : rl.Vector3,
	albedo_secondary : rl.Vector3,
	scale : f32,
	image_name : string, //map key
}

texture_lib := make(map[string]rl.Image)

texture_solid :: proc(tex : texture, u : f32, v : f32, p : rl.Vector3) -> rl.Vector3 {
	return tex.albedo
}

texture_checkerboard :: proc(tex : texture, u : f32, v : f32, p : rl.Vector3) -> rl.Vector3 {
		inv_scale : f32 = 1.0 / tex.scale
		xInteger : i32 = i32(math.floor_f32(inv_scale * p.x))
		yInteger : i32 = i32(math.floor_f32(inv_scale * p.y))
		zInteger : i32 = i32(math.floor_f32(inv_scale * p.z))

        isEven : bool = (xInteger + yInteger + zInteger) % 2 == 0

        return isEven ? tex.albedo : tex.albedo_secondary
}

texture_image :: proc(tex : texture, u : f32, v : f32, p : rl.Vector3) -> rl.Vector3 {
	// If we have no texture data, then return solid cyan as a debugging aid.
	if tex.image_name == "" do return {0,1,1}

	tex_image : rl.Image = texture_lib[tex.image_name]
	// wrap before clamp
	_, u2 := math.modf_f32(u)
	_, v2 := math.modf_f32(v) 
	// Clamp input texture coordinates to [0,1] x [1,0]
	u2 = clamp(u2, 0.0, 1.0)
	v2 = 1.0 - clamp(v2, 0.0, 1.0)  // Flip V to image coordinates
	
	i : i32 = i32(math.floor_f32(u2 * f32(tex_image.width-1)))
	j : i32 = i32(math.floor_f32(v2 * f32(tex_image.height-1)))
	pixel_i : rl.Color = rl.GetImageColor(tex_image, i, j)

	pixel_f : rl.Vector4 = rl.ColorNormalize(pixel_i)
	return {pixel_f.x, pixel_f.y, pixel_f.z}
}

// make this systemic
texture_lib_load :: proc() {
	tex_world : rl.Image = rl.LoadImage("W:/Dropbox/code/odin/Odini/textures/earthmap.png")
	texture_lib["world"] = tex_world
	fmt.println("tex loaded")
}

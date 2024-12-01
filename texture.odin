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
	image_idx : i32, //index for now
}

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
	if tex.image_idx == -1 do return {0,1,1}
	//fmt.println("u:", u, "v:", v)

	tex_image : rl.Image = texture_lib[tex.image_idx]
	// Clamp input texture coordinates to [0,1] x [1,0]
	u2 : f32 = clamp(u, 0.0, 1.0)
	v2 : f32 = 1.0 - clamp(v, 0.0, 1.0)  // Flip V to image coordinates
	
	i : i32 = i32(u2 * f32(tex_image.width))
	j : i32 = i32(v2 * f32(tex_image.height))
	pixel_i : rl.Color = rl.GetImageColor(tex_image, i, j)

	pixel_f : rl.Vector4 = rl.ColorNormalize(pixel_i)
	return {pixel_f.x, pixel_f.y, pixel_f.z}
}

texture_lib_load :: proc() {
	tex_world : rl.Image = rl.LoadImage("W:/Dropbox/code/odin/Odini/textures/earthmap.png")
	fmt.println("tex loaded")
	append(&texture_lib, tex_world)
}
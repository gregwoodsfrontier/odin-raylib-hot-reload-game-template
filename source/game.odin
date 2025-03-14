/*
This file is the starting point of your game.

Some important procedures are:
- game_init_window: Opens the window
- game_init: Sets up the game state
- game_update: Run once per frame
- game_should_close: For stopping your game when close button is pressed
- game_shutdown: Shuts down game and frees memory
- game_shutdown_window: Closes window

The procs above are used regardless if you compile using the `build_release`
script or the `build_hot_reload` script. However, in the hot reload case, the
contents of this file is compiled as part of `build/hot_reload/game.dll` (or
.dylib/.so on mac/linux). In the hot reload cases some other procedures are
also used in order to facilitate the hot reload functionality:

- game_memory: Run just before a hot reload. That way game_hot_reload.exe has a
      pointer to the game's memory that it can hand to the new game DLL.
- game_hot_reloaded: Run after a hot reload so that the `g_mem` global
      variable can be set to whatever pointer it was in the old DLL.

NOTE: When compiled as part of `build_release`, `build_debug` or `build_web`
then this whole package is just treated as a normal Odin package. No DLL is
created.
*/

package game

import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
import "core:slice"
import rl "vendor:raylib"

PIXEL_WINDOW_HEIGHT :: 180
BACKGROUND_SCALE :: 2
ENTITY_SCALE :: 4
MAX_POOL_SIZE :: 100
SPAWN_RATE :: 1.0

BlockType :: enum {
	TREE,
	BRANCH,
	TRUNK,
	BIG_TREE,
	BIG_BRANCH,
}

BlockId :: distinct int
Roadblock :: struct {
    pos : rl.Vector2,
	vec: rl.Vector2,
	type: BlockType,
	body: rl.Rectangle,
	id: BlockId,
	active: bool,
}

BG :: struct {
	scroll_vec: rl.Vector2,
	positions : [2]rl.Vector2,
	texture: rl.Texture,
}

BG_SIDE :: enum {
	TOP,
	BOTTOM,
}

Player :: struct {
	vel: rl.Vector2,
	acc: rl.Vector2,
	pos: rl.Vector2,
	frame_coords: [2]int,
}
Game_Memory :: struct {
	spawn_timer: f32,
	roadblocks: [MAX_POOL_SIZE]Roadblock,
	pool_active_num: int,
	rb_id: BlockId,
	bg_scroll_vec: rl.Vector2,
	bg_pos: [2]rl.Vector2,
	bg_texture: rl.Texture,
	tilemap_texture: rl.Texture,
	frame_size: int,
	player_pos: rl.Vector2,
	player_frame_coords: [2]int,
	player_texture: rl.Texture,
	player_vec: f32,
	player_body: rl.Rectangle,
	walls: [2]rl.Rectangle,
	some_number: int,
	run: bool,
}

g_mem: ^Game_Memory

game_camera :: proc() -> rl.Camera2D {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())

	return {
		zoom = h/PIXEL_WINDOW_HEIGHT,
		target = g_mem.player_pos,
		offset = { w/2, h/2 },
	}
}

ui_camera :: proc() -> rl.Camera2D {
	return {
		zoom = f32(rl.GetScreenHeight())/PIXEL_WINDOW_HEIGHT,
	}
}

spawn_roadblock :: proc(_position: rl.Vector2) {
	for &blk in g_mem.roadblocks {
		// find the first inactive block and activate it
		if !blk.active {
			blk.pos = _position
			blk.vec = g_mem.bg_scroll_vec
			blk.type = .TREE
			blk.body = rl.Rectangle {
				x = blk.pos.x,
				y = blk.pos.y,
				width = 16 * ENTITY_SCALE,
				height = 16 * ENTITY_SCALE,
			}
			blk.id = g_mem.rb_id
			blk.active = true
			g_mem.rb_id += 1
			break
		}
	}
}

despawn_roadblock :: proc(id: BlockId) {
	// find the specific element with same id and deactivate it. zero everything ?
	for &e in g_mem.roadblocks {
		if(e.id == id) {
			e.active = false
			e.pos = {0,0}
			e.vec = {0,0}
			e.body = rl.Rectangle {0,0,0,0}
			break
		}
	}
}

update :: proc() {
	// update the spawn road block timer
	g_mem.spawn_timer -= rl.GetFrameTime()

	if g_mem.spawn_timer <= 0 {
		rad_f := rand.float32() * 0.5
		spawn_roadblock({
			f32(rl.GetScreenWidth()) * (0.2 + rad_f),
			f32(rl.GetScreenHeight()),
		})
		// resets the timer back to spawn rate
		g_mem.spawn_timer += SPAWN_RATE + g_mem.spawn_timer
	}

	input: rl.Vector2

	if rl.IsKeyDown(.UP) || rl.IsKeyDown(.W) {
		input.y -= 1
	}
	if rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S) {
		input.y += 1
	}
	if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
		input.x -= 1
	}
	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
		input.x += 1
	}

	input = linalg.normalize0(input)
	g_mem.player_pos += input * rl.GetFrameTime() * g_mem.player_vec
	g_mem.player_body.x = g_mem.player_pos.x
	g_mem.player_body.y = g_mem.player_pos.y
	
	if rl.IsKeyPressed(.ESCAPE) {
		g_mem.run = false
	}

	// check if bottom bg has scrolled to top screen, resets all bg pos
	if (g_mem.bg_pos[BG_SIDE.BOTTOM].y <= 0) {
		g_mem.bg_pos[BG_SIDE.TOP].y = 0
		g_mem.bg_pos[BG_SIDE.BOTTOM].y = f32(g_mem.bg_texture.height) * BACKGROUND_SCALE
	}

	// scroll the background ski
	for &bgPos in g_mem.bg_pos {
		bgPos += g_mem.bg_scroll_vec * rl.GetFrameTime()
	}

	for &el in g_mem.roadblocks {
		if(el.active) {
			el.pos += el.vec * rl.GetFrameTime()
			el.body.x = el.pos.x
			el.body.y = el.pos.y

			// remove roadblock if offscreen
			if el.pos.y <= 10 {
				despawn_roadblock(el.id)
			}
		}
	}
	
	// count the number of active rb
	is_active :: proc(el: Roadblock) -> bool {
		return el.active
	}
	g_mem.pool_active_num = slice.count_proc(g_mem.roadblocks[:], is_active)
}

draw_roadblocks :: proc() {
	for el in g_mem.roadblocks {
		if(el.active) {
			rl.DrawRectangleRec(el.body, rl.YELLOW)
		}
	}
}

draw_player :: proc() {
	draw_player_src := rl.Rectangle {
		x = f32(g_mem.frame_size * g_mem.player_frame_coords.x),
		y = f32(g_mem.frame_size * g_mem.player_frame_coords.y),
		width = f32(g_mem.frame_size),
		height = f32(g_mem.frame_size),
	}

	draw_player_dest := rl.Rectangle {
		x = f32(g_mem.player_pos.x),
		y = f32(g_mem.player_pos.y),
		width = f32(g_mem.frame_size * ENTITY_SCALE),
		height = f32(g_mem.frame_size * ENTITY_SCALE),
	}

	rl.DrawTexturePro(
		g_mem.tilemap_texture,
		draw_player_src,
		draw_player_dest,
		{0,0},
		0,
		rl.WHITE,
	)
}

draw_player_body :: proc() {
	rl.DrawRectangleRec(g_mem.player_body, rl.BEIGE)
}

draw_wall_bodies :: proc() {
	for wall in g_mem.walls {
		rl.DrawRectangleRec(wall, rl.Color{0,255,0,128})
	}
}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLUE)
	
	draw_bg_source := rl.Rectangle{
		x = 0,
		y = 0,
		width = f32(g_mem.bg_texture.width),
		height = f32(g_mem.bg_texture.height),
	}

	draw_top_bg_dest := rl.Rectangle {
		x = g_mem.bg_pos[0].x,
		y = g_mem.bg_pos[0].y,
		width = f32(g_mem.bg_texture.width*BACKGROUND_SCALE),
		height = f32(g_mem.bg_texture.height*BACKGROUND_SCALE),
	}

	draw_bot_bg_dest := rl.Rectangle {
		x = g_mem.bg_pos[1].x,
		y = g_mem.bg_pos[1].y,
		width = f32(g_mem.bg_texture.width*BACKGROUND_SCALE),
		height = f32(g_mem.bg_texture.height*BACKGROUND_SCALE),
	}
	// draw top bg
	rl.DrawTexturePro(
		g_mem.bg_texture, 
		draw_bg_source, 
		draw_top_bg_dest, 
		{0, 0},
		0,
		rl.WHITE,
	)
	// draw bottom bg
	rl.DrawTexturePro(
		g_mem.bg_texture, 
		draw_bg_source, 
		draw_bot_bg_dest, 
		{0, 0},
		0,
		rl.WHITE,
	)

	// rl.BeginMode2D(game_camera())
	draw_player()
	draw_player_body()
	draw_wall_bodies()
	draw_roadblocks()


	// rl.EndMode2D()

	rl.BeginMode2D(ui_camera())

	// NOTE: `fmt.ctprintf` uses the temp allocator. The temp allocator is
	// cleared at the end of the frame by the main application, meaning inside
	// `main_hot_reload.odin`, `main_release.odin` or `main_web_entry.odin`.
	
	rl.DrawText(fmt.ctprintf("active_rb: %v\nplayer_pos: %v", g_mem.pool_active_num, g_mem.player_pos), 5, 5, 8, rl.WHITE)
	

	rl.EndMode2D()

	rl.EndDrawing()
}

@(export)
game_update :: proc() {
	update()
	draw()
}

@(export)
game_init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1280, 720, "Odin Hot Jam! Pathways")
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(500)
	rl.SetExitKey(nil)
}

@(export)
game_init :: proc() {
	g_mem = new(Game_Memory)
	bg_grid_size := f32(16 * BACKGROUND_SCALE)
	g_mem^ = Game_Memory {
		run = true,
		some_number = 100,

		// You can put textures, sounds and music in the `assets` folder. Those
		// files will be part any release or web build.
		tilemap_texture = rl.LoadTexture("assets/tilemap_packed.png"),
		player_texture = rl.LoadTexture("assets/round_cat.png"),
		player_frame_coords = {10, 6},
		frame_size = 16,
		player_pos = {f32(rl.GetScreenWidth()/2) - 16/2*ENTITY_SCALE, f32(rl.GetScreenHeight())*0.2 - - 16/2*ENTITY_SCALE},
		player_vec = 250.00,
		bg_texture = rl.LoadTexture("assets/ski-world.png"),
		bg_pos = {
			{0, 0},
			{0, f32(rl.GetScreenHeight())},
		},
		bg_scroll_vec = {0, -180},
		rb_id = 0,
		walls = {
			rl.Rectangle {
				x = 0,
				y = 0,
				width = bg_grid_size * 6,
				height = f32(rl.GetScreenHeight()),
			},
			rl.Rectangle {
				x = f32(rl.GetScreenWidth()) - bg_grid_size * 6,
				y = 0,
				width = bg_grid_size * 6,
				height = f32(rl.GetScreenHeight()),
			},
		},
	}
	g_mem.player_body = rl.Rectangle {
		x = g_mem.player_pos.x,
		y = g_mem.player_pos.y,
		width = f32(g_mem.frame_size * ENTITY_SCALE),
		height = f32(g_mem.frame_size * ENTITY_SCALE),
	}


	game_hot_reloaded(g_mem)
}

@(export)
game_should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		// Never run this proc in browser. It contains a 16 ms sleep on web!
		if rl.WindowShouldClose() {
			return false
		}
	}

	return g_mem.run
}

@(export)
game_shutdown :: proc() {
	free(g_mem)
}

@(export)
game_shutdown_window :: proc() {
	rl.CloseWindow()
}

@(export)
game_memory :: proc() -> rawptr {
	return g_mem
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(Game_Memory)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	g_mem = (^Game_Memory)(mem)

	// Here you can also set your own global variables. A good idea is to make
	// your global variables into pointers that point to something inside
	// `g_mem`.
}

@(export)
game_force_reload :: proc() -> bool {
	return rl.IsKeyPressed(.F5)
}

@(export)
game_force_restart :: proc() -> bool {
	return rl.IsKeyPressed(.F6)
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
game_parent_window_size_changed :: proc(w, h: int) {
	rl.SetWindowSize(i32(w), i32(h))
}

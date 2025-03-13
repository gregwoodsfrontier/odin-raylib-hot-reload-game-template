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
import rl "vendor:raylib"

PIXEL_WINDOW_HEIGHT :: 180
BACKGROUND_SCALE :: 2
ENTITY_SCALE :: 4
MAX_POOL_SIZE :: 4000
BlockPool :: struct {
    slots:         [MAX_POOL_SIZE]Slot,
    next_free_idx: int, // points to the next free slot
    n_slots_used:  int, // number of slots that are occupied by an int or a Bullet
}

Slot :: union #no_nil {
    int,    // points at next free slot idx
    Roadblock, // stores roadblock data
}

BlockType :: enum {
	TREE,
	BRANCH,
	TRUNK,
	BIG_TREE,
	BIG_BRANCH,
}
Roadblock :: struct {
    pos : rl.Vector2,
	vec: rl.Vector2,
	type: BlockType,
	body: rl.Rectangle,
}

BlockId :: distinct int // just an index into the bullet pool

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
	bg_scroll_vec: rl.Vector2,
	bg_pos: [2]rl.Vector2,
	bg_texture: rl.Texture,
	tilemap_texture: rl.Texture,
	frame_size: int,
	player_pos: rl.Vector2,
	player_frame_coords: [2]int,
	player_texture: rl.Texture,
	player_vec: f32,
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

update :: proc() {
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
	g_mem.some_number += 1

	if rl.IsKeyPressed(.ESCAPE) {
		g_mem.run = false
	}

	// check if bottom bg has scrolled to top screen, resets all bg pos
	if (g_mem.bg_pos[BG_SIDE.BOTTOM].y <= 0) {
		g_mem.bg_pos[BG_SIDE.TOP].y = 0
		g_mem.bg_pos[BG_SIDE.BOTTOM].y = f32(g_mem.bg_texture.height) * BACKGROUND_SCALE
	}

	for &bgPos in g_mem.bg_pos {
		bgPos += g_mem.bg_scroll_vec * rl.GetFrameTime()
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
	// rl.DrawTextureEx(g_mem.player_texture, g_mem.player_pos, 0, 1, rl.WHITE)
	rl.DrawRectangleV({520, 520}, {10, 10}, rl.RED)
	rl.DrawRectangleV({530, 520}, {10, 10}, rl.GREEN)


	// rl.EndMode2D()

	rl.BeginMode2D(ui_camera())

	// NOTE: `fmt.ctprintf` uses the temp allocator. The temp allocator is
	// cleared at the end of the frame by the main application, meaning inside
	// `main_hot_reload.odin`, `main_release.odin` or `main_web_entry.odin`.
	rl.DrawText(fmt.ctprintf("some_number: %v\nplayer_pos: %v", g_mem.some_number, g_mem.player_pos), 5, 5, 8, rl.WHITE)

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
		player_vec = 100.00,
		bg_texture = rl.LoadTexture("assets/ski-world.png"),
		bg_pos = {
			{0, 0},
			{0, f32(rl.GetScreenHeight())},
		},
		bg_scroll_vec = {0, -200},
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

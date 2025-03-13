package game2

MAX_N_BULLETS :: 4000
BulletPool :: struct {
    slots:         [4000]Slot,
    next_free_idx: int, // points to the next free slot
    n_slots_used:  int, // number of slots that are occupied by an int or a Bullet
}
NSlot :: union #no_nil {
    int,    // points at next free slot idx
    Bullet, // stores bullet data
}
Bullet :: struct {
    pos:      Vec2,
    velocity: Vec2,
}
BulletId :: distinct int // just an index into the bullet pool

// add new bullet to pool, returns idx of bullet. Returns -1 if all 4000 slots are taken
bullet_pool_add :: proc(using pool: ^BulletPool, bullet: Bullet) -> (id: BulletId) {
    if next_free_idx == n_slots_used {
        // add new bullet to the end because all slots[0..n_slots_used] are occupied by bullets, 
        if n_slots_used == MAX_N_BULLETS do return -1

        id = BulletId(n_slots_used)
        slots[id] = bullet
        pool.n_slots_used += 1
        pool.next_free_idx += 1
    } else {
        // put the bullet in the next free slot:
        id = BulletId(next_free_idx)
        slot := &slots[id]
        pool.next_free_idx = slot.(int) or_else panic("slot should contain int!") // slots form linked list
        slot^ = bullet
    }
    return id
}
// removes a bullet from the pool
bullet_pool_remove :: proc(using pool: ^BulletPool, id: BulletId) -> (bullet: Bullet, success: bool) {
    if id < 0 || int(id) >= n_slots_used {
        return {}, false
    }
    slot := &slots[id]
    if bullet_in_slot, ok := slot.(Bullet); ok {
        // use this slot as an element in the linked list of free slots
        slot^ = pool.next_free_idx
        pool.next_free_idx = int(id)
        return bullet_in_slot, true
    } else {
        // unexptected, bullet id does not point to occupied slot
        return {}, false
    }
}

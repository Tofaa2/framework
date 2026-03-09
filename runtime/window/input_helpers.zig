const std = @import("std");
const input = @import("input.zig");

/// Helper utilities for common input patterns
pub const InputHelpers = struct {
    
    /// Check if a standard "save" shortcut was pressed (Ctrl+S or Cmd+S on Mac)
    pub fn isSaveShortcut(state: *input.InputState) bool {
        return (state.modifiers.ctrl or state.modifiers.super) and 
               state.isKeyJustPressed(.S);
    }
    
    /// Check if a standard "open" shortcut was pressed (Ctrl+O or Cmd+O on Mac)
    pub fn isOpenShortcut(state: *input.InputState) bool {
        return (state.modifiers.ctrl or state.modifiers.super) and 
               state.isKeyJustPressed(.O);
    }
    
    /// Check if a standard "copy" shortcut was pressed (Ctrl+C or Cmd+C on Mac)
    pub fn isCopyShortcut(state: *input.InputState) bool {
        return (state.modifiers.ctrl or state.modifiers.super) and 
               state.isKeyJustPressed(.C);
    }
    
    /// Check if a standard "paste" shortcut was pressed (Ctrl+V or Cmd+V on Mac)
    pub fn isPasteShortcut(state: *input.InputState) bool {
        return (state.modifiers.ctrl or state.modifiers.super) and 
               state.isKeyJustPressed(.V);
    }
    
    /// Check if a standard "cut" shortcut was pressed (Ctrl+X or Cmd+X on Mac)
    pub fn isCutShortcut(state: *input.InputState) bool {
        return (state.modifiers.ctrl or state.modifiers.super) and 
               state.isKeyJustPressed(.X);
    }
    
    /// Check if a standard "undo" shortcut was pressed (Ctrl+Z or Cmd+Z on Mac)
    pub fn isUndoShortcut(state: *input.InputState) bool {
        return (state.modifiers.ctrl or state.modifiers.super) and 
               !state.modifiers.shift and
               state.isKeyJustPressed(.Z);
    }
    
    /// Check if a standard "redo" shortcut was pressed (Ctrl+Y or Ctrl+Shift+Z)
    pub fn isRedoShortcut(state: *input.InputState) bool {
        if ((state.modifiers.ctrl or state.modifiers.super) and state.isKeyJustPressed(.Y)) {
            return true;
        }
        if ((state.modifiers.ctrl or state.modifiers.super) and state.modifiers.shift and state.isKeyJustPressed(.Z)) {
            return true;
        }
        return false;
    }
    
    /// Check if a standard "select all" shortcut was pressed (Ctrl+A or Cmd+A on Mac)
    pub fn isSelectAllShortcut(state: *input.InputState) bool {
        return (state.modifiers.ctrl or state.modifiers.super) and 
               state.isKeyJustPressed(.A);
    }
    
    /// Check if a standard "find" shortcut was pressed (Ctrl+F or Cmd+F on Mac)
    pub fn isFindShortcut(state: *input.InputState) bool {
        return (state.modifiers.ctrl or state.modifiers.super) and 
               state.isKeyJustPressed(.F);
    }
    
    /// Get WASD movement vector (-1, 0, or 1 for each axis)
    pub fn getWASDMovement(state: *input.InputState) struct { x: i32, y: i32 } {
        var x: i32 = 0;
        var y: i32 = 0;
        
        if (state.isKeyPressed(.W)) y -= 1;
        if (state.isKeyPressed(.S)) y += 1;
        if (state.isKeyPressed(.A)) x -= 1;
        if (state.isKeyPressed(.D)) x += 1;
        
        return .{ .x = x, .y = y };
    }
    
    /// Get arrow key movement vector (-1, 0, or 1 for each axis)
    pub fn getArrowMovement(state: *input.InputState) struct { x: i32, y: i32 } {
        var x: i32 = 0;
        var y: i32 = 0;
        
        if (state.isKeyPressed(.Up)) y -= 1;
        if (state.isKeyPressed(.Down)) y += 1;
        if (state.isKeyPressed(.Left)) x -= 1;
        if (state.isKeyPressed(.Right)) x += 1;
        
        return .{ .x = x, .y = y };
    }
    
    /// Check if any modifier key is currently pressed
    pub fn isAnyModifierPressed(state: *input.InputState) bool {
        return state.modifiers.shift or 
               state.modifiers.ctrl or 
               state.modifiers.alt or 
               state.modifiers.super;
    }
    
    /// Format modifier keys into a string (e.g., "Ctrl+Shift")
    /// Caller owns the returned memory
    pub fn formatModifiers(allocator: std.mem.Allocator, modifiers: input.Modifiers) ![]u8 {
        if (!modifiers.shift and !modifiers.ctrl and !modifiers.alt and !modifiers.super) {
            return try allocator.dupe(u8, "");
        }
        
        var parts: [4][]const u8 = undefined;
        var count: usize = 0;
        
        if (modifiers.ctrl) {
            parts[count] = "Ctrl";
            count += 1;
        }
        if (modifiers.shift) {
            parts[count] = "Shift";
            count += 1;
        }
        if (modifiers.alt) {
            parts[count] = "Alt";
            count += 1;
        }
        if (modifiers.super) {
            parts[count] = "Super";
            count += 1;
        }
        
        return try std.mem.join(allocator, "+", parts[0..count]);
    }
    
    /// Check if a specific key combination is pressed
    /// Example: isKeyCombination(state, &[_]Key{.Control, .Shift, .N})
    pub fn isKeyCombination(state: *input.InputState, keys: []const input.Key) bool {
        for (keys) |key| {
            if (!state.isKeyPressed(key)) {
                return false;
            }
        }
        return true;
    }
    
    /// Check if mouse is over a rectangular area
    pub fn isMouseOverRect(state: *input.InputState, x: i32, y: i32, width: i32, height: i32) bool {
        const mouse_pos = state.getMousePosition();
        return mouse_pos.x >= x and 
               mouse_pos.x < x + width and
               mouse_pos.y >= y and 
               mouse_pos.y < y + height;
    }
    
    /// Check if left mouse button was clicked inside a rectangular area
    pub fn wasRectClicked(state: *input.InputState, x: i32, y: i32, width: i32, height: i32) bool {
        return state.isMouseButtonJustPressed(.Left) and 
               isMouseOverRect(state, x, y, width, height);
    }
};

/// Key chord builder for complex keyboard shortcuts
pub const KeyChord = struct {
    modifiers: input.Modifiers,
    key: input.Key,
    
    pub fn init(key: input.Key) KeyChord {
        return .{
            .modifiers = .{},
            .key = key,
        };
    }
    
    pub fn withCtrl(self: KeyChord) KeyChord {
        var result = self;
        result.modifiers.ctrl = true;
        return result;
    }
    
    pub fn withShift(self: KeyChord) KeyChord {
        var result = self;
        result.modifiers.shift = true;
        return result;
    }
    
    pub fn withAlt(self: KeyChord) KeyChord {
        var result = self;
        result.modifiers.alt = true;
        return result;
    }
    
    pub fn withSuper(self: KeyChord) KeyChord {
        var result = self;
        result.modifiers.super = true;
        return result;
    }
    
    pub fn matches(self: KeyChord, state: *input.InputState) bool {
        if (!state.isKeyJustPressed(self.key)) {
            return false;
        }
        
        // Check that all required modifiers are pressed
        if (self.modifiers.ctrl and !state.modifiers.ctrl) return false;
        if (self.modifiers.shift and !state.modifiers.shift) return false;
        if (self.modifiers.alt and !state.modifiers.alt) return false;
        if (self.modifiers.super and !state.modifiers.super) return false;
        
        // Check that no extra modifiers are pressed
        if (!self.modifiers.ctrl and state.modifiers.ctrl) return false;
        if (!self.modifiers.shift and state.modifiers.shift) return false;
        if (!self.modifiers.alt and state.modifiers.alt) return false;
        if (!self.modifiers.super and state.modifiers.super) return false;
        
        return true;
    }
};

/// Input action mapper - map keys to named actions
pub const ActionMapper = struct {
    const ActionMap = std.StringHashMap(KeyChord);
    
    allocator: std.mem.Allocator,
    actions: ActionMap,
    
    pub fn init(allocator: std.mem.Allocator) ActionMapper {
        return .{
            .allocator = allocator,
            .actions = ActionMap.init(allocator),
        };
    }
    
    pub fn deinit(self: *ActionMapper) void {
        var iter = self.actions.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.actions.deinit();
    }
    
    pub fn bind(self: *ActionMapper, action_name: []const u8, chord: KeyChord) !void {
        const key = try self.allocator.dupe(u8, action_name);
        try self.actions.put(key, chord);
    }
    
    pub fn isActionTriggered(self: *ActionMapper, action_name: []const u8, state: *input.InputState) bool {
        const chord = self.actions.get(action_name) orelse return false;
        return chord.matches(state);
    }
    
    pub fn unbind(self: *ActionMapper, action_name: []const u8) void {
        if (self.actions.fetchRemove(action_name)) |entry| {
            self.allocator.free(entry.key);
        }
    }
};

// Usage examples in comments:

// Standard shortcuts:
// if (InputHelpers.isSaveShortcut(input_state)) { save(); }
// if (InputHelpers.isPasteShortcut(input_state)) { paste(); }

// Movement:
// const movement = InputHelpers.getWASDMovement(input_state);
// player.x += movement.x * speed;
// player.y += movement.y * speed;

// UI rectangles:
// if (InputHelpers.wasRectClicked(input_state, button_x, button_y, button_w, button_h)) {
//     onButtonClick();
// }

// Key chords:
// const save_chord = KeyChord.init(.S).withCtrl();
// if (save_chord.matches(input_state)) { save(); }

// Action mapping:
// var mapper = ActionMapper.init(allocator);
// try mapper.bind("save", KeyChord.init(.S).withCtrl());
// try mapper.bind("quit", KeyChord.init(.Q).withCtrl());
// 
// if (mapper.isActionTriggered("save", input_state)) { save(); }
// if (mapper.isActionTriggered("quit", input_state)) { quit(); }

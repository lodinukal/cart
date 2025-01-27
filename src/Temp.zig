const Self = @This();

buffer: []u8 = &.{},
fbas: []std.heap.FixedBufferAllocator = &.{},
index: usize = 0,

pub const Options = struct {
    /// the maximum number of memory that can be ephemerally allocated per frame
    per_frame_allocation_limit: usize = 10_000,
    /// how many frames of memory to keep around
    frame_count: usize = 2,
};

pub fn init(alloc: std.mem.Allocator, options: Self.Options) !Self {
    const buffer = try alloc.alloc(
        u8,
        options.per_frame_allocation_limit * options.frame_count,
    );
    const fbas = try alloc.alloc(
        std.heap.FixedBufferAllocator,
        options.frame_count,
    );

    for (fbas, 0..) |*fba, i| {
        fba.* = .{
            .buffer = buffer[i * options.per_frame_allocation_limit ..][0..options.per_frame_allocation_limit],
            .end_index = 0,
        };
    }

    return .{
        .buffer = buffer,
        .fbas = fbas,
        .index = 0,
    };
}

pub fn deinit(self: Self, alloc: std.mem.Allocator) void {
    alloc.free(self.buffer);
    alloc.free(self.fbas);
}

pub fn allocator(self: *const Self) std.mem.Allocator {
    return self.fbas[self.index].allocator();
}

pub fn nextFrame(self: *Self) void {
    self.index = (self.index + 1) % self.fbas.len;
    self.fbas[self.index].reset();
}

pub fn currentCapacity(self: *const Self) usize {
    return self.fbas[self.index].buffer.len - self.fbas[self.index].end_index;
}

const std = @import("std");

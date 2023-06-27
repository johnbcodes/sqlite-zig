const std = @import("std");
const sqlite = @import("sqlite");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        std.debug.panic("leaks detected", .{});
    };

    var allocator = gpa.allocator();

    var db = try sqlite.Db.init(.{
        .mode = sqlite.Db.Mode{ .File = "data.db" },
        .open_flags = .{ .write = true, .create = true },
    });
    defer db.deinit();

    // Set desired pragmas
    _ = try db.pragma(void, .{}, "journal_mode", "wal");
    _ = try db.pragma(void, .{}, "synchronous", "normal");
    _ = try db.pragma(void, .{}, "foreign_keys", "on");

    // Create a table
    try db.exec("CREATE TABLE user(id integer primary key, age integer, name text)", .{}, .{});

    // Insert some data
    const insert: []const u8 = "INSERT INTO user(id, age, name) VALUES($id{usize}, $age{u32}, $name{[]const u8})";
    const user_name: []const u8 = "Vincent";
    try db.exec(insert, .{}, .{ @as(usize, 10), @as(u32, 34), user_name });
    try db.exec(insert, .{}, .{ @as(usize, 20), @as(u32, 84), @as([]const u8, "José") });

    var stmt = try db.prepare("SELECT id, name, age FROM user where id > 99 order by id");
    defer stmt.deinit();

    const rows = try stmt.all(
        struct {
            id: usize,
            name: []const u8,
            age: usize,
        },
        allocator,
        .{},
        .{},
    );

    for (rows) |row| {
        allocator.free(row.name);
    }
    allocator.free(rows);
}

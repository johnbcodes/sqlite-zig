const std = @import("std");
const sqlite = @import("sqlite");

const Person = struct {
    id: usize,
    age: u32,
    name: []const u8,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        std.debug.panic("leaks detected", .{});
    };

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    var allocator = arena.allocator();

    std.fs.cwd().deleteFile("data.db") catch |e| {
        switch (e) {
            error.FileNotFound => {},
            else => return e,
        }
    };

    var db = try sqlite.Db.init(.{
        .mode = .{ .File = "data.db" },
        .open_flags = .{ .write = true, .create = true },
    });
    defer db.deinit();

    // Set desired pragmas
    _ = try db.pragma(void, .{}, "journal_mode", "wal");
    _ = try db.pragma(void, .{}, "synchronous", "normal");
    _ = try db.pragma(void, .{}, "foreign_keys", "on");

    // Create a table
    try db.exec("CREATE TABLE user(id integer primary key, age integer, name text) strict", .{}, .{});

    var marge = Person{ .id = 1, .age = 34, .name = "Marge" };
    var homer = Person{ .id = 2, .age = 36, .name = "Homer" };

    // Insert some data
    const insert: []const u8 = "INSERT INTO user(id, age, name) VALUES($id{usize}, $age{u32}, $name{[]const u8})";
    try db.exec(insert, .{}, marge);
    try db.exec(insert, .{}, homer);

    var stmt = try db.prepare("SELECT id, name, age FROM user order by id");
    defer stmt.deinit();

    _ = try stmt.all(
        Person,
        allocator,
        .{},
        .{},
    );
}

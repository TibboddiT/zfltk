const zfltk = @import("zfltk");
const app = zfltk.app;
const Window = zfltk.window.Window;
const Box = zfltk.box.Box;
const Button = zfltk.button.Button;
const Tile = zfltk.group.Tile;
const Color = zfltk.enums.Color;

pub fn main() !void {
    try app.init();

    var win = try Window.init(.{
        .w = 400,
        .h = 300,

        .label = "Tile group",
    });

    var tile = try Tile.init(.{
        .w = 400,
        .h = 300,
    });

    win.resizable(tile);

    var btn = try Button.init(.{
        .x = 0,
        .y = 48,
        .w = tile.w() - 48,
        .h = 48,
        .label = "Button",
    });

    // This demonstrates how you can add inline widgets which have no purpose
    // besides aesthetics. This could be useful for spacers and whatnot
    tile.add(.{
        try Box.init(.{
            .x = 0,
            .y = 0,
            .w = tile.w() - 48,
            .h = 48,
            .boxtype = .down,
        }),
        btn,
        try Box.init(.{
            .x = 0,
            .y = 96,
            .w = tile.w() - 48,
            .h = tile.h() - 96,
            .boxtype = .down,
            .label = "Try dragging between\nwidget borders!",
        }),
        try Box.init(.{
            .x = tile.w() - 48,
            .y = 0,
            .w = 48,
            .h = tile.h(),
            .boxtype = .down,
        }),
    });

    tile.end();

    win.end();
    win.show();
    try app.run();
}

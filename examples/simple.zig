const zfltk = @import("zfltk");
const app = zfltk.app;
const widget = zfltk.widget;
const window = zfltk.window;
const button = zfltk.button;
const box = zfltk.box;
const enums = zfltk.enums;

pub fn butCb(w: widget.WidgetPtr, data: ?*c_void) callconv(.C) void {
    var mybox = widget.Widget.fromVoidPtr(data);
    mybox.setLabel("Hello World!");
    var but = button.Button.fromWidgetPtr(w); // You can still use a Widget.fromWidgetPtr
    but.asWidget().setColor(enums.Color.Cyan);
}

pub fn main() !void {
    try app.init();
    app.setScheme(.Gtk);
    var win = window.Window.new(100, 100, 400, 300, "Hello");
    var but = button.Button.new(160, 200, 80, 40, "Click");
    var mybox = box.Box.new(0, 0, 400, 200, "");
    win.asGroup().end();
    win.asWidget().show();
    but.asWidget().setCallback(butCb, @ptrCast(?*c_void, mybox.raw()));
    try app.run();
}

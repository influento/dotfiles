#!/usr/bin/env python3
"""Calendar popup for waybar — native GTK4 calendar widget with Catppuccin Mocha theme."""

import os, sys

# gtk4-layer-shell must be loaded before libwayland-client
if "LD_PRELOAD" not in os.environ:
    os.environ["LD_PRELOAD"] = "/usr/lib/libgtk4-layer-shell.so"
    os.execvp(sys.argv[0], sys.argv)

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gtk, Gdk, Gtk4LayerShell

CSS = """
window {
  background-color: transparent;
}

.calendar-container {
  background-color: @@BASE@@;
  color: @@TEXT@@;
}

calendar {
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 14px;
  background-color: @@BASE@@;
  color: @@TEXT@@;
  padding: 8px;
}

calendar > header {
  background-color: @@MANTLE@@;
  border-radius: 8px;
  padding: 4px;
}

calendar > header > button {
  color: @@BLUE@@;
  min-height: 24px;
  min-width: 24px;
}

calendar > header > button:hover {
  background-color: @@SURFACE1@@;
  border-radius: 4px;
}

calendar.view {
  background-color: @@BASE@@;
}

calendar > grid > label.day-name {
  color: @@MAUVE@@;
  font-weight: bold;
}

calendar > grid > label.day-number {
  color: @@TEXT@@;
  border-radius: 50%;
  padding: 4px;
}

calendar > grid > label.day-number:selected {
  background-color: @@BLUE@@;
  color: @@BASE@@;
  font-weight: bold;
}

calendar > grid > label.day-number.other-month {
  color: @@SURFACE2@@;
}
"""


class CalendarPopup(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.dotfiles.calendar-popup")

    def do_activate(self):
        # Load CSS
        provider = Gtk.CssProvider()
        provider.load_from_string(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        win = Gtk.ApplicationWindow(application=self, title="calendar-popup")

        # Layer-shell: fullscreen transparent overlay (catches clicks everywhere)
        Gtk4LayerShell.init_for_window(win)
        Gtk4LayerShell.set_layer(win, Gtk4LayerShell.Layer.OVERLAY)
        Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.TOP, True)
        Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.BOTTOM, True)
        Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.LEFT, True)
        Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.RIGHT, True)
        Gtk4LayerShell.set_keyboard_mode(win, Gtk4LayerShell.KeyboardMode.EXCLUSIVE)

        # Transparent backdrop — clicking it closes the popup
        overlay = Gtk.Overlay()
        backdrop = Gtk.DrawingArea()
        backdrop.set_hexpand(True)
        backdrop.set_vexpand(True)
        backdrop_click = Gtk.GestureClick()
        backdrop_click.connect("released", lambda *_: self.quit())
        backdrop.add_controller(backdrop_click)
        overlay.set_child(backdrop)

        # Calendar widget at top-center (same size as before)
        calendar_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        calendar_box.add_css_class("calendar-container")
        calendar_box.set_halign(Gtk.Align.CENTER)
        calendar_box.set_valign(Gtk.Align.START)
        calendar_box.set_margin_top(40)

        calendar = Gtk.Calendar()
        calendar.set_margin_top(8)
        calendar.set_margin_bottom(8)
        calendar.set_margin_start(8)
        calendar.set_margin_end(8)
        calendar_box.append(calendar)
        overlay.add_overlay(calendar_box)

        # Close on Escape or q
        controller = Gtk.EventControllerKey()
        controller.connect("key-pressed", self._on_key)
        win.add_controller(controller)

        win.set_child(overlay)
        win.present()

    def _on_key(self, controller, keyval, keycode, state):
        if keyval in (Gdk.KEY_Escape, Gdk.KEY_q):
            self.quit()
            return True
        return False


if __name__ == "__main__":
    CalendarPopup().run()

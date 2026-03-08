#!/usr/bin/env python3
import os, subprocess, sys

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

.power-container {
  background-color: @@BASE@@;
  color: @@TEXT@@;
  border: 1px solid @@SURFACE1@@;
  border-radius: 8px;
  padding: 16px 24px;
}

.power-button {
  background: transparent;
  border: none;
  border-radius: 8px;
  padding: 12px 16px;
  min-width: 64px;
}

.power-button:hover {
  background-color: @@SURFACE0@@;
}

.power-icon {
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 28px;
}

.power-label {
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 11px;
  color: @@SUBTEXT0@@;
}

.color-blue  .power-icon { color: @@BLUE@@; }
.color-mauve .power-icon { color: @@MAUVE@@; }
.color-peach .power-icon { color: @@PEACH@@; }
.color-red   .power-icon { color: @@RED@@; }
"""

ACTIONS = [
    ("󰌾", "Lock",      "color-blue",  [os.path.expanduser("~/.local/bin/lock")]),
    ("󰤄", "Sleep",     "color-mauve", ["systemctl", "suspend"]),
    ("󰜉", "Reboot",    "color-peach", ["systemctl", "reboot"]),
    ("󰐥", "Shut Down", "color-red",   ["systemctl", "poweroff"]),
]


class PowerPopup(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.dotfiles.power-popup")

    def do_activate(self):
        provider = Gtk.CssProvider()
        provider.load_from_string(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        win = Gtk.ApplicationWindow(application=self, title="power-popup")

        Gtk4LayerShell.init_for_window(win)
        Gtk4LayerShell.set_layer(win, Gtk4LayerShell.Layer.OVERLAY)
        Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.TOP, True)
        Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.BOTTOM, True)
        Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.LEFT, True)
        Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.RIGHT, True)
        Gtk4LayerShell.set_keyboard_mode(win, Gtk4LayerShell.KeyboardMode.EXCLUSIVE)

        overlay = Gtk.Overlay()
        backdrop = Gtk.DrawingArea()
        backdrop.set_hexpand(True)
        backdrop.set_vexpand(True)
        backdrop_click = Gtk.GestureClick()
        backdrop_click.connect("released", lambda *_: self.quit())
        backdrop.add_controller(backdrop_click)
        overlay.set_child(backdrop)

        container = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        container.add_css_class("power-container")
        container.set_halign(Gtk.Align.CENTER)
        container.set_valign(Gtk.Align.START)
        container.set_margin_top(40)

        for icon, label, color_class, cmd in ACTIONS:
            btn = Gtk.Button()
            btn.add_css_class("power-button")
            btn.add_css_class(color_class)

            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
            box.set_halign(Gtk.Align.CENTER)

            icon_label = Gtk.Label(label=icon)
            icon_label.add_css_class("power-icon")
            box.append(icon_label)

            text_label = Gtk.Label(label=label)
            text_label.add_css_class("power-label")
            box.append(text_label)

            btn.set_child(box)
            btn.connect("clicked", self._on_action, cmd)
            container.append(btn)

        overlay.add_overlay(container)

        controller = Gtk.EventControllerKey()
        controller.connect("key-pressed", self._on_key)
        win.add_controller(controller)

        win.set_child(overlay)
        win.present()

    def _on_action(self, button, cmd):
        self.quit()
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def _on_key(self, controller, keyval, keycode, state):
        if keyval in (Gdk.KEY_Escape, Gdk.KEY_q):
            self.quit()
            return True
        return False


if __name__ == "__main__":
    PowerPopup().run()

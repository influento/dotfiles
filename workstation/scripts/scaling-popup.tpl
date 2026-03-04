#!/usr/bin/env python3
import json, os, subprocess, sys

# gtk4-layer-shell must be loaded before libwayland-client
if "LD_PRELOAD" not in os.environ:
    os.environ["LD_PRELOAD"] = "/usr/lib/libgtk4-layer-shell.so"
    os.execvp(sys.argv[0], sys.argv)

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gtk, Gdk, GLib, Gtk4LayerShell

CSS = """
window {
  background-color: transparent;
}

.scaling-container {
  background-color: @@BASE@@;
  color: @@TEXT@@;
  border: 1px solid @@SURFACE1@@;
  border-radius: 8px;
  padding: 16px 24px;
}

.scaling-title {
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 14px;
  font-weight: bold;
  color: @@BLUE@@;
}

.scaling-value {
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 24px;
  font-weight: bold;
  color: @@TEXT@@;
}

scale {
  min-width: 280px;
}

scale trough {
  background-color: @@SURFACE0@@;
  border-radius: 4px;
  min-height: 8px;
}

scale highlight {
  background-color: @@SAPPHIRE@@;
  border-radius: 4px;
  min-height: 8px;
}

scale slider {
  background-color: @@SAPPHIRE@@;
  border-radius: 50%;
  min-width: 20px;
  min-height: 20px;
  margin: -6px;
}

scale indicator {
  color: @@SUBTEXT0@@;
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 10px;
}
"""


def get_current_scale():
    """Read the current scale of the first active output from swaymsg."""
    try:
        result = subprocess.run(
            ["swaymsg", "-t", "get_outputs"], capture_output=True, text=True
        )
        outputs = json.loads(result.stdout)
        for output in outputs:
            if output.get("active"):
                return output.get("scale", 1.0)
    except Exception:
        pass
    return 1.0


def apply_scale(scale):
    """Apply scale to all outputs via swaymsg and persist to sway config."""
    subprocess.run(
        ["swaymsg", "output", "*", "scale", f"{scale:.1f}"],
        capture_output=True,
    )
    conf = os.path.expanduser("~/.config/sway/scale.conf")
    with open(conf, "w") as f:
        f.write(f"output * scale {scale:.1f}\n")


class ScalingPopup(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.dotfiles.scaling-popup")
        self._apply_timeout = 0

    def do_activate(self):
        # Load CSS
        provider = Gtk.CssProvider()
        provider.load_from_string(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        win = Gtk.ApplicationWindow(application=self, title="scaling-popup")

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

        # Scaling container at top-center
        container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        container.add_css_class("scaling-container")
        container.set_halign(Gtk.Align.CENTER)
        container.set_valign(Gtk.Align.START)
        container.set_margin_top(40)

        # Title
        title = Gtk.Label(label="Display Scale")
        title.add_css_class("scaling-title")
        container.append(title)

        # Percentage label
        current = get_current_scale()
        self._value_label = Gtk.Label(label=f"{int(current * 100)}%")
        self._value_label.add_css_class("scaling-value")
        container.append(self._value_label)

        # Slider
        adjustment = Gtk.Adjustment(
            value=current, lower=1.0, upper=2.0,
            step_increment=0.1, page_increment=0.1,
        )
        scale = Gtk.Scale(orientation=Gtk.Orientation.HORIZONTAL, adjustment=adjustment)
        scale.set_draw_value(False)
        scale.set_digits(1)
        for i in range(11):
            val = 1.0 + i * 0.1
            scale.add_mark(val, Gtk.PositionType.BOTTOM, None)
        scale.add_mark(1.0, Gtk.PositionType.TOP, "100%")
        scale.add_mark(1.5, Gtk.PositionType.TOP, "150%")
        scale.add_mark(2.0, Gtk.PositionType.TOP, "200%")
        adjustment.connect("value-changed", self._on_scale_changed)
        container.append(scale)

        overlay.add_overlay(container)

        # Close on Escape or q
        controller = Gtk.EventControllerKey()
        controller.connect("key-pressed", self._on_key)
        win.add_controller(controller)

        win.set_child(overlay)
        win.present()

    def _on_scale_changed(self, adjustment):
        raw = adjustment.get_value()
        snapped = round(raw * 10) / 10
        self._value_label.set_text(f"{int(snapped * 100)}%")
        if self._apply_timeout:
            GLib.source_remove(self._apply_timeout)
        self._apply_timeout = GLib.timeout_add(500, self._apply_pending, snapped)

    def _apply_pending(self, scale_value):
        self._apply_timeout = 0
        apply_scale(scale_value)
        return GLib.SOURCE_REMOVE

    def _on_key(self, controller, keyval, keycode, state):
        if keyval in (Gdk.KEY_Escape, Gdk.KEY_q):
            self.quit()
            return True
        return False


if __name__ == "__main__":
    ScalingPopup().run()

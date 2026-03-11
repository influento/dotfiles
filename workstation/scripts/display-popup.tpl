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

.display-container {
  background-color: @@BASE@@;
  color: @@TEXT@@;
  border: 1px solid @@SURFACE1@@;
  border-radius: 8px;
  padding: 16px 24px;
}

.display-title {
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 14px;
  font-weight: bold;
  color: @@BLUE@@;
}

.section-label {
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 11px;
  font-weight: bold;
  color: @@SUBTEXT0@@;
  margin-top: 4px;
}

.section-value {
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 20px;
  font-weight: bold;
  color: @@TEXT@@;
}

separator {
  background-color: @@SURFACE1@@;
  min-height: 1px;
  margin: 4px 0;
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

TEMP_FILE = os.path.expanduser("~/.config/wlsunset/temperature")


def get_current_scale():
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
    subprocess.run(
        ["swaymsg", "output", "*", "scale", f"{scale:.1f}"],
        capture_output=True,
    )
    conf = os.path.expanduser("~/.config/sway/scale.conf")
    with open(conf, "w") as f:
        f.write(f"output * scale {scale:.1f}\n")
    subprocess.Popen(["pkill", "-RTMIN+11", "waybar"],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def detect_brightness_backend():
    """Return 'backlight', 'ddc', or None."""
    try:
        result = subprocess.run(
            ["brightnessctl", "-c", "backlight", "info"],
            capture_output=True, text=True,
        )
        if result.returncode == 0:
            return "backlight"
    except FileNotFoundError:
        pass
    try:
        result = subprocess.run(
            ["ddcutil", "getvcp", "10"], capture_output=True, text=True,
        )
        if result.returncode == 0:
            return "ddc"
    except FileNotFoundError:
        pass
    return None


def get_brightness(backend):
    if backend == "backlight":
        try:
            cur = int(subprocess.run(
                ["brightnessctl", "-c", "backlight", "get"],
                capture_output=True, text=True,
            ).stdout.strip())
            mx = int(subprocess.run(
                ["brightnessctl", "-c", "backlight", "max"],
                capture_output=True, text=True,
            ).stdout.strip())
            return round(cur * 100 / mx)
        except Exception:
            return 100
    else:
        try:
            result = subprocess.run(
                ["ddcutil", "getvcp", "10"], capture_output=True, text=True,
            )
            # Output: "VCP code 0x10 (...): current value =   45, max value =  100"
            for part in result.stdout.split(","):
                if "current value" in part:
                    return int(part.split("=")[1].strip())
        except Exception:
            pass
        return 100


def apply_brightness(backend, pct):
    pct = int(pct)
    if backend == "backlight":
        subprocess.run(
            ["brightnessctl", "-c", "backlight", "set", f"{pct}%"],
            capture_output=True,
        )
    else:
        subprocess.run(
            ["ddcutil", "setvcp", "10", str(pct)],
            capture_output=True,
        )


def get_temperature():
    try:
        with open(TEMP_FILE) as f:
            return int(f.read().strip())
    except Exception:
        return 4500


def apply_temperature(temp):
    temp = int(temp)
    os.makedirs(os.path.dirname(TEMP_FILE), exist_ok=True)
    with open(TEMP_FILE, "w") as f:
        f.write(f"{temp}\n")
    subprocess.run(["pkill", "wlsunset"], capture_output=True)
    subprocess.Popen(
        ["wlsunset", "-T", str(temp + 1), "-t", str(temp)],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        start_new_session=True,
    )


class DisplayPopup(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.dotfiles.display-popup")
        self._timeouts = {"scale": 0, "brightness": 0, "temperature": 0}

    def do_activate(self):
        provider = Gtk.CssProvider()
        provider.load_from_string(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        win = Gtk.ApplicationWindow(application=self, title="display-popup")

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

        container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        container.add_css_class("display-container")
        container.set_halign(Gtk.Align.CENTER)
        container.set_valign(Gtk.Align.START)
        container.set_margin_top(40)

        title = Gtk.Label(label="Display")
        title.add_css_class("display-title")
        container.append(title)

        # --- Scale ---
        self._build_slider(
            container, "SCALE", get_current_scale(), lambda v: f"{int(v * 100)}%",
            1.0, 2.0, 0.1,
            marks=[(1.0, "100%"), (1.5, "150%"), (2.0, "200%")],
            ticks=[1.0 + i * 0.1 for i in range(11)],
            snap=lambda v: round(v * 10) / 10,
            key="scale", delay=500, apply_fn=apply_scale,
        )

        # --- Brightness (backlight or DDC/CI) ---
        brightness_backend = detect_brightness_backend()
        if brightness_backend:
            delay = 100 if brightness_backend == "backlight" else 500
            container.append(Gtk.Separator())
            self._build_slider(
                container, "BRIGHTNESS",
                get_brightness(brightness_backend) / 100,
                lambda v: f"{int(v * 100)}%",
                0.0, 1.0, 0.05,
                marks=[(0.0, "0%"), (0.5, "50%"), (1.0, "100%")],
                ticks=[i * 0.1 for i in range(11)],
                snap=lambda v: round(v * 20) / 20,
                key="brightness", delay=delay,
                apply_fn=lambda v: apply_brightness(brightness_backend, v * 100),
            )

        # --- Night Light ---
        container.append(Gtk.Separator())
        self._build_slider(
            container, "NIGHT LIGHT", get_temperature() / 1000,
            lambda v: f"{int(v * 1000)}K",
            2.5, 6.5, 0.1,
            marks=[(2.5, "2500K"), (4.5, "4500K"), (6.5, "6500K")],
            ticks=[2.5 + i * 0.5 for i in range(9)],
            snap=lambda v: round(v * 10) / 10,
            key="temperature", delay=500,
            apply_fn=lambda v: apply_temperature(v * 1000),
        )

        overlay.add_overlay(container)

        controller = Gtk.EventControllerKey()
        controller.connect("key-pressed", self._on_key)
        win.add_controller(controller)

        win.set_child(overlay)
        win.present()

    def _build_slider(self, container, label_text, current, fmt_fn,
                      lower, upper, step, marks, ticks, snap,
                      key, delay, apply_fn):
        label = Gtk.Label(label=label_text)
        label.add_css_class("section-label")
        label.set_halign(Gtk.Align.START)
        container.append(label)

        value_label = Gtk.Label(label=fmt_fn(current))
        value_label.add_css_class("section-value")
        container.append(value_label)

        adj = Gtk.Adjustment(
            value=current, lower=lower, upper=upper,
            step_increment=step, page_increment=step,
        )
        scale = Gtk.Scale(orientation=Gtk.Orientation.HORIZONTAL, adjustment=adj)
        scale.set_draw_value(False)
        scale.set_digits(2)
        for t in ticks:
            scale.add_mark(t, Gtk.PositionType.BOTTOM, None)
        for val, text in marks:
            scale.add_mark(val, Gtk.PositionType.TOP, text)
        adj.connect("value-changed", self._on_slider_changed,
                    value_label, fmt_fn, snap, key, delay, apply_fn)
        container.append(scale)

    def _on_slider_changed(self, adj, value_label, fmt_fn, snap,
                           key, delay, apply_fn):
        snapped = snap(adj.get_value())
        value_label.set_text(fmt_fn(snapped))
        if self._timeouts[key]:
            GLib.source_remove(self._timeouts[key])
        self._timeouts[key] = GLib.timeout_add(
            delay, self._apply, key, apply_fn, snapped
        )

    def _apply(self, key, apply_fn, value):
        self._timeouts[key] = 0
        apply_fn(value)
        return GLib.SOURCE_REMOVE

    def _on_key(self, controller, keyval, keycode, state):
        if keyval in (Gdk.KEY_Escape, Gdk.KEY_q):
            self.quit()
            return True
        return False


if __name__ == "__main__":
    DisplayPopup().run()

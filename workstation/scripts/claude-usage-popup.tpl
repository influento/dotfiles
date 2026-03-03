#!/usr/bin/env python3
"""Claude usage popup — GTK4 widget showing subscription utilization with progress bars."""

import json, os, subprocess, sys, urllib.request

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

.usage-container {
  background-color: @@BASE@@;
  color: @@TEXT@@;
  border-radius: 8px;
  padding: 16px 24px;
  min-width: 320px;
}

.usage-title {
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 14px;
  font-weight: bold;
  color: @@BLUE@@;
}

.refresh-button {
  background: transparent;
  border: none;
  color: @@OVERLAY1@@;
  font-size: 14px;
  padding: 0 4px;
  min-height: 0;
  min-width: 0;
}

.refresh-button:hover {
  color: @@BLUE@@;
}

.usage-window-label {
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 12px;
  color: @@TEXT@@;
}

.usage-pct {
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 12px;
  font-weight: bold;
}

.usage-reset {
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 10px;
  color: @@SUBTEXT0@@;
}

.usage-error {
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 12px;
  color: @@SURFACE2@@;
}

.usage-separator {
  background-color: @@SURFACE0@@;
  min-height: 1px;
  margin: 4px 0;
}

.usage-charge-label {
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 11px;
  color: @@SUBTEXT0@@;
}

.session-label {
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 10px;
  color: @@SUBTEXT0@@;
}

.session-entry {
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 11px;
  background-color: @@SURFACE0@@;
  color: @@TEXT@@;
  border: 1px solid @@SURFACE2@@;
  border-radius: 4px;
  padding: 4px 8px;
  min-width: 280px;
}

.session-entry:focus {
  border-color: @@BLUE@@;
}

.session-button {
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 11px;
  background-color: @@BLUE@@;
  color: @@BASE@@;
  border: none;
  border-radius: 4px;
  padding: 4px 12px;
}

.session-button:hover {
  background-color: @@SAPPHIRE@@;
}

.session-status {
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 10px;
}

.session-status-ok { color: @@GREEN@@; }
.session-status-err { color: @@RED@@; }

progressbar trough {
  background-color: @@SURFACE0@@;
  border-radius: 4px;
  min-height: 8px;
}

progressbar progress {
  border-radius: 4px;
  min-height: 8px;
}

progressbar.low progress {
  background-color: @@GREEN@@;
}

progressbar.medium progress {
  background-color: @@YELLOW@@;
}

progressbar.high progress {
  background-color: @@RED@@;
}

.pct-low { color: @@GREEN@@; }
.pct-medium { color: @@YELLOW@@; }
.pct-high { color: @@RED@@; }
"""

from datetime import date, datetime, timezone
from pathlib import Path

CACHE_PATH = Path.home() / ".claude" / "subscription_cache.json"


def fetch_data(force=False):
    """Call claude-usage --json and return parsed data."""
    cmd = [os.path.expanduser("~/.local/bin/claude-usage"), "--json"]
    if force:
        cmd.append("--refresh")
    result = subprocess.run(cmd, capture_output=True, text=True)
    return json.loads(result.stdout)


def format_reset(iso_str):
    """Format reset as absolute day/time + relative duration."""
    reset = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
    local = reset.astimezone()
    absolute = local.strftime("%a %-I:%M %p")
    now = datetime.now(timezone.utc)
    delta = reset - now
    total_minutes = int(delta.total_seconds() / 60)
    if total_minutes < 0:
        return "resets now"
    total_hours, minutes = divmod(total_minutes, 60)
    if total_hours >= 24:
        days, hours = divmod(total_hours, 24)
        relative = f"{days}d {hours}h"
    elif total_hours > 0:
        relative = f"{total_hours}h {minutes}m"
    else:
        relative = f"{minutes}m"
    return f"resets {absolute} ({relative})"


def format_charge_date(date_str):
    """Format charge date as absolute + relative."""
    target = datetime.strptime(date_str, "%Y-%m-%d")
    absolute = target.strftime("%b %-d")
    target_utc = target.replace(tzinfo=timezone.utc)
    now = datetime.now(timezone.utc)
    delta = target_utc - now
    total_hours = int(delta.total_seconds() / 3600)
    if total_hours < 0:
        return f"{absolute} (now)"
    if total_hours >= 24:
        days, hours = divmod(total_hours, 24)
        return f"{absolute} ({days}d {hours}h)"
    minutes = int((delta.total_seconds() % 3600) / 60)
    return f"{absolute} ({total_hours}h {minutes}m)"


def classify(pct):
    """Return CSS class based on utilization percentage."""
    if pct > 95:
        return "high"
    if pct >= 80:
        return "medium"
    return "low"


def has_valid_cache():
    """Check if cached charge date exists and is in the future."""
    try:
        with open(CACHE_PATH) as f:
            cache = json.load(f)
        charge_date = cache.get("next_charge_date")
        if charge_date and datetime.strptime(charge_date, "%Y-%m-%d").date() >= date.today():
            return True
    except (FileNotFoundError, json.JSONDecodeError, KeyError, ValueError):
        pass
    return False


def fetch_subscription(session_key, org_uuid):
    """Fetch subscription details using session key cookie."""
    url = f"https://api.anthropic.com/api/organizations/{org_uuid}/subscription_details"
    req = urllib.request.Request(url, headers={
        "Content-Type": "application/json",
        "Cookie": f"sessionKey={session_key}",
    })
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read())


def get_org_uuid(force_refresh=False):
    """Get org UUID from cache or OAuth profile."""
    if not force_refresh:
        try:
            with open(CACHE_PATH) as f:
                cached = json.load(f).get("org_uuid")
            if cached:
                return cached
        except (FileNotFoundError, json.JSONDecodeError):
            pass
    creds_path = Path.home() / ".claude" / ".credentials.json"
    with open(creds_path) as f:
        token = json.load(f)["claudeAiOauth"]["accessToken"]
    req = urllib.request.Request(
        "https://api.anthropic.com/api/oauth/profile",
        headers={
            "Authorization": f"Bearer {token}",
            "anthropic-beta": "oauth-2025-04-20",
        },
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read())["organization"]["uuid"]


class ClaudeUsagePopup(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.dotfiles.claude-usage-popup")

    def do_activate(self):
        # Load CSS
        provider = Gtk.CssProvider()
        provider.load_from_string(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        win = Gtk.ApplicationWindow(application=self, title="claude-usage-popup")

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

        # Main container at top-center
        self._container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        self._container.add_css_class("usage-container")
        self._container.set_halign(Gtk.Align.CENTER)
        self._container.set_valign(Gtk.Align.START)
        self._container.set_margin_top(40)

        self._build_content()

        overlay.add_overlay(self._container)

        # Close on Escape or q
        controller = Gtk.EventControllerKey()
        controller.connect("key-pressed", self._on_key)
        win.add_controller(controller)

        win.set_child(overlay)
        win.present()

    def _build_content(self, force=False):
        """Build or rebuild all content in the container."""
        # Clear existing children
        while child := self._container.get_first_child():
            self._container.remove(child)

        # Title row with refresh button
        title_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        title = Gtk.Label(label="Claude Usage")
        title.add_css_class("usage-title")
        title.set_hexpand(True)
        title.set_halign(Gtk.Align.START)
        title_row.append(title)

        refresh_btn = Gtk.Button(label="󰑓")
        refresh_btn.add_css_class("refresh-button")
        refresh_btn.set_tooltip_text("Refresh usage data")
        refresh_btn.connect("clicked", lambda _: self._build_content(force=True))
        title_row.append(refresh_btn)

        self._container.append(title_row)

        # Fetch data
        try:
            data = fetch_data(force=force)
            if "error" in data:
                raise RuntimeError(data["error"])
            self._build_window_row(self._container, "5-hour", data["five_hour"])
            self._build_window_row(self._container, "7-day", data["seven_day"])
            sonnet = data.get("seven_day_sonnet")
            if sonnet and sonnet.get("utilization") is not None:
                self._build_window_row(self._container, "7-day sonnet", sonnet)
            self._build_charge_section(self._container, data)
        except Exception:
            error_label = Gtk.Label(label="Failed to fetch usage data")
            error_label.add_css_class("usage-error")
            self._container.append(error_label)

    def _build_window_row(self, container, name, window_data):
        """Build a labeled progress bar row for one usage window."""
        pct = window_data["utilization"]
        level = classify(pct)

        # Header row: name + percentage
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)

        name_label = Gtk.Label(label=name)
        name_label.add_css_class("usage-window-label")
        name_label.set_hexpand(True)
        name_label.set_halign(Gtk.Align.START)
        header.append(name_label)

        pct_label = Gtk.Label(label=f"{round(pct)}%")
        pct_label.add_css_class("usage-pct")
        pct_label.add_css_class(f"pct-{level}")
        header.append(pct_label)

        container.append(header)

        # Progress bar
        bar = Gtk.ProgressBar()
        bar.set_fraction(min(pct / 100.0, 1.0))
        bar.add_css_class(level)
        container.append(bar)

        # Reset time
        reset_label = Gtk.Label(label=format_reset(window_data["resets_at"]))
        reset_label.add_css_class("usage-reset")
        reset_label.set_halign(Gtk.Align.START)
        container.append(reset_label)

    def _build_charge_section(self, container, data):
        """Show charge date if cached, or session key input if not."""
        separator = Gtk.Separator()
        separator.add_css_class("usage-separator")
        container.append(separator)

        charge_date = data.get("next_charge_date")
        if charge_date:
            label = Gtk.Label(label=f"next charge: {format_charge_date(charge_date)}")
            label.add_css_class("usage-charge-label")
            label.set_halign(Gtk.Align.START)
            container.append(label)
            return

        # No valid cache — show session key input
        hint = Gtk.Label(label="paste session key to fetch billing info")
        hint.add_css_class("session-label")
        hint.set_halign(Gtk.Align.START)
        container.append(hint)

        input_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)

        self._session_entry = Gtk.Entry()
        self._session_entry.set_placeholder_text("sk-ant-sid02-...")
        self._session_entry.add_css_class("session-entry")
        self._session_entry.set_hexpand(True)
        self._session_entry.set_visibility(False)
        self._session_entry.connect("activate", lambda _: self._on_submit())
        input_row.append(self._session_entry)

        submit_btn = Gtk.Button(label="save")
        submit_btn.add_css_class("session-button")
        submit_btn.connect("clicked", lambda _: self._on_submit())
        input_row.append(submit_btn)

        container.append(input_row)

        self._status_label = Gtk.Label()
        self._status_label.set_halign(Gtk.Align.START)
        container.append(self._status_label)

    def _on_submit(self):
        """Fetch subscription details and cache the result."""
        session_key = self._session_entry.get_text().strip()
        if not session_key:
            return

        try:
            org_uuid = get_org_uuid()
            try:
                sub = fetch_subscription(session_key, org_uuid)
            except urllib.error.HTTPError as e:
                if e.code == 404:
                    org_uuid = get_org_uuid(force_refresh=True)
                    sub = fetch_subscription(session_key, org_uuid)
                else:
                    raise
            charge_date = sub.get("next_charge_date")
            if not charge_date:
                raise ValueError("no next_charge_date in response")

            cache = {"next_charge_date": charge_date, "org_uuid": org_uuid}
            with open(CACHE_PATH, "w") as f:
                json.dump(cache, f)

            self._status_label.set_text(f"saved — next charge: {format_charge_date(charge_date)}")
            self._status_label.remove_css_class("session-status-err")
            self._status_label.add_css_class("session-status")
            self._status_label.add_css_class("session-status-ok")
            self._session_entry.set_text("")
        except Exception as e:
            self._status_label.set_text(f"failed: {e}")
            self._status_label.remove_css_class("session-status-ok")
            self._status_label.add_css_class("session-status")
            self._status_label.add_css_class("session-status-err")

    def _on_key(self, controller, keyval, keycode, state):
        if keyval in (Gdk.KEY_Escape, Gdk.KEY_q):
            self.quit()
            return True
        return False


if __name__ == "__main__":
    ClaudeUsagePopup().run()

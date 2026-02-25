/* SwayOSD — On-screen display for volume/brightness */

window {
  background: alpha(@@BASE@@, 0.85);
  border-radius: 12px;
  border: 1px solid @@SURFACE1@@;
  padding: 12px 20px;
  color: @@TEXT@@;
}

#container {
  margin: 8px;
}

image {
  color: @@LAVENDER@@;
  margin-right: 8px;
}

progressbar:disabled,
image:disabled {
  opacity: 0.5;
}

progressbar {
  min-height: 6px;
  border-radius: 999px;
  background: none;
}

trough {
  min-height: 6px;
  border-radius: 999px;
  background-color: @@SURFACE0@@;
}

progress {
  min-height: 6px;
  border-radius: 999px;
  background-color: @@LAVENDER@@;
}

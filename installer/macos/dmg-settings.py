import os


application = os.path.abspath(defines["app"])  # noqa: F821
app_name = "AI Limit Status.app"

format = "UDZO"
filesystem = "HFS+"
compression_level = 9

files = [(application, app_name)]
symlinks = {"Applications": "/Applications"}
# The packaging script points Finder at the background inside the signed app.
# Do not create a standalone PNG that appears when hidden files are visible.
background = None
# Finder stores outer bounds; allow 32 points for the macOS title bar above
# the 720 x 440 design area. These bounds set the initial size, not a lock.
window_rect = ((120, 120), (720, 472))
default_view = "icon-view"

show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False

include_icon_view_settings = True
arrange_by = None
grid_offset = (0, 0)
grid_spacing = 80
scroll_position = (0, 0)
label_pos = "bottom"
text_size = 13
icon_size = 96

icon_locations = {
    app_name: (183, 171),
    "Applications": (537, 171),
}

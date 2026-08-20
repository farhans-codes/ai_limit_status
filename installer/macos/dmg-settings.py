import os


application = os.path.abspath(defines["app"])  # noqa: F821
background_image = os.path.abspath(defines["background"])  # noqa: F821
app_name = "AI Limit Status.app"

format = "UDZO"
filesystem = "HFS+"
compression_level = 9

files = [(application, app_name)]
symlinks = {"Applications": "/Applications"}
hide = [".background.png"]

background = background_image
window_rect = ((120, 120), (720, 440))
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
    ".background.png": (0, 0),
}

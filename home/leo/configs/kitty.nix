_:

{
  xdg.configFile."kitty/kitty.conf".text = ''
    font_family Iosevka Term
    font_size 10.0
    background_opacity 0.95
    scrollback_lines 100000
    allow_remote_control yes
    listen_on unix:/tmp/kitty-socket

    # Disable synthetic bold
    disable_ligatures never
    bold_font auto
    italic_font auto
    bold_italic_font auto

    # Enable window splitting
    enabled_layouts splits,stack

    # Disable default Ctrl+Shift+Enter split (use Ctrl+x>3 / Ctrl+x>2 instead)
    map ctrl+shift+enter no_op

    # Emacs-style window splitting keybindings
    map ctrl+x>2 launch --location=hsplit --cwd=current
    map ctrl+x>3 launch --location=vsplit --cwd=current
    map ctrl+x>0 close_window
    map ctrl+x>b kitten broadcast

    # Window navigation
    map ctrl+shift+left neighboring_window left
    map ctrl+shift+right neighboring_window right
    map ctrl+shift+up neighboring_window up
    map ctrl+shift+down neighboring_window down

    # Window resizing
    # Press Ctrl+Shift+R, then use mouse to click and drag window borders
    # Or use arrow keys after pressing Ctrl+Shift+R
    map ctrl+shift+r start_resizing_window

    # Alternative: direct keyboard shortcuts for resizing
    map alt+left resize_window narrower
    map alt+right resize_window wider
    map alt+up resize_window taller
    map alt+down resize_window shorter
    map alt+home resize_window reset

    # Font size
    map ctrl+plus change_font_size all +1.0
    map ctrl+minus change_font_size all -1.0

    # Tab navigation
    map ctrl+left previous_tab
    map ctrl+right next_tab

    # Prevent closing the last tab/window with Ctrl+D
    confirm_os_window_close 1

    # Wild Cherry theme
    foreground #d9faff
    background #1f1626

    # Normal colors
    color0 #000506
    color1 #d94085
    color2 #2ab250
    color3 #ffd16f
    color4 #883cdc
    color5 #ececec
    color6 #c1b8b7
    color7 #fff8dd

    # Bright colors
    color8  #009cc9
    color9  #da6bab
    color10 #f4dba5
    color11 #eac066
    color12 #2f8bb9
    color13 #ae636b
    color14 #ff919d
    color15 #e4838d
  '';
}

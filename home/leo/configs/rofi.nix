_:

{
  xdg.configFile."rofi/config.rasi".text = ''
    configuration {
      modi: "drun,run,window";
      show-icons: true;
      display-drun: "Applications";
      display-run: "Run";
      display-window: "Windows";
      drun-display-format: "{name}";
      terminal: "kitty --class dropdown-terminal";
      font: "Iosevka Term 11";
    }

    * {
      background:     #1f1626;
      foreground:     #d9faff;
      selected:       #883cdc;
      selected-foreground: #fff8dd;
      border-color:   #d94085;
      urgent:         #d94085;
      active:         #2ab250;
    }

    window {
      location: north west;
      anchor: north west;
      width: 32%;
      y-offset: 34px;
      x-offset: 8px;
      border: 2px;
      border-radius: 0px;
      padding: 0px;
      background-color: @background;
    }

    mainbox {
      children: [ inputbar, listview ];
      spacing: 0px;
      background-color: @background;
    }

    inputbar {
      padding: 12px;
      border: 0px 0px 2px 0px;
      border-color: @border-color;
      background-color: @background;
      text-color: @foreground;
    }

    prompt {
      text-color: @selected;
      margin: 0px 8px 0px 0px;
    }

    entry {
      text-color: @foreground;
      placeholder: "Search...";
      placeholder-color: #c1b8b7;
    }

    listview {
      lines: 10;
      columns: 1;
      fixed-height: false;
      border: 0px;
      spacing: 0px;
      scrollbar: false;
      background-color: @background;
    }

    element {
      padding: 10px;
      border: 0px;
      background-color: @background;
      text-color: @foreground;
    }

    element normal.normal {
      background-color: @background;
      text-color: @foreground;
    }

    element alternate.normal {
      background-color: @background;
      text-color: @foreground;
    }

    element selected {
      background-color: @selected;
      text-color: @selected-foreground;
    }

    element selected.normal {
      background-color: @selected;
      text-color: @selected-foreground;
    }

    element-icon {
      size: 18px;
      margin: 0px 8px 0px 0px;
      background-color: transparent;
    }

    element-text {
      text-color: inherit;
      background-color: transparent;
    }
  '';
}

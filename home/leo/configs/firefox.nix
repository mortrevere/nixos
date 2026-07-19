_:

{
  programs.firefox = {
    enable = true;
    profiles.default = {
      isDefault = true;
      settings = {
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        # GPU acceleration
        "gfx.webrender.all" = true;
        "media.ffmpeg.vaapi.enabled" = true;
        "media.hardware-video-decoding.force-enabled" = true;
        "media.hardware-video-decoding.enabled" = true;
        "widget.dmabuf.force-enabled" = true;
        "layers.acceleration.force-enabled" = true;
        "gfx.canvas.accelerated" = true;
      };
      userChrome = ''
        /* UI font */
        * {
          font-family: "Iosevka Term" !important;
        }

        /* Hide menu bar, revealed by pressing Alt */
        #toolbar-menubar {
          visibility: collapse !important;
        }
        #toolbar-menubar:focus-within {
          visibility: visible !important;
        }

        /* ── System color theme ── */
        :root {
          --toolbar-bgcolor: #1f1626 !important;
          --toolbar-color: #d9faff !important;
          --toolbar-field-background-color: #2a1e33 !important;
          --toolbar-field-color: #d9faff !important;
          --toolbar-field-border-color: #3a2848 !important;
          --toolbar-field-focus-background-color: #2a1e33 !important;
          --toolbar-field-focus-color: #d9faff !important;
          --toolbar-field-focus-border-color: #883cdc !important;
          --lwt-accent-color: #1f1626 !important;
          --lwt-text-color: #d9faff !important;
          --tab-selected-bgcolor: #883cdc !important;
          --tab-selected-textcolor: #fff8dd !important;
          --tab-loading-fill: #d94085 !important;
          --arrowpanel-background: #1f1626 !important;
          --arrowpanel-color: #d9faff !important;
          --arrowpanel-border-color: #3a2848 !important;
          --sidebar-background-color: #1f1626 !important;
          --sidebar-text-color: #d9faff !important;
          --sidebar-border-color: #3a2848 !important;
          --urlbar-box-bgcolor: #2a1e33 !important;
          --urlbar-box-hover-bgcolor: #3a2848 !important;
          --urlbar-box-active-bgcolor: #3a2848 !important;
          --urlbar-box-text-color: #d9faff !important;
          --button-bgcolor: #2a1e33 !important;
          --button-hover-bgcolor: #3a2848 !important;
          --button-active-bgcolor: #883cdc !important;
          --button-color: #d9faff !important;
          --toolbarbutton-icon-fill: #d9faff !important;
          --autocomplete-popup-background: #1f1626 !important;
          --autocomplete-popup-color: #d9faff !important;
          --autocomplete-popup-highlight-background: #883cdc !important;
          --autocomplete-popup-highlight-color: #fff8dd !important;
          --focus-outline-color: #883cdc !important;
        }

        /* Navigator toolbox */
        #navigator-toolbox {
          background-color: #1f1626 !important;
          border-bottom: 1px solid #3a2848 !important;
        }

        #nav-bar {
          background-color: #1f1626 !important;
          box-shadow: none !important;
        }

        /* URL bar */
        #urlbar-background {
          background-color: #2a1e33 !important;
          border: 1px solid #3a2848 !important;
        }
        #urlbar[focused] > #urlbar-background {
          border-color: #883cdc !important;
        }

        /* Tabs toolbar background */
        #TabsToolbar {
          background-color: #1f1626 !important;
        }

        /* Tab appearance */
        .tabbrowser-tab .tab-background {
          background-color: transparent !important;
          border-radius: 6px !important;
          margin-block: 1px !important;
        }
        .tabbrowser-tab[selected] .tab-background {
          background-color: #883cdc !important;
        }
        .tabbrowser-tab:hover:not([selected]) .tab-background {
          background-color: #2a1e33 !important;
        }
        .tab-label {
          color: #d9faff !important;
        }
        .tabbrowser-tab[selected] .tab-label {
          color: #fff8dd !important;
        }

        /* Sidebar (vertical tabs) */
        #sidebar-main {
          background-color: #1f1626 !important;
        }
        #sidebar-box {
          background-color: #1f1626 !important;
        }

        /* Findbar */
        findbar {
          background-color: #1f1626 !important;
          color: #d9faff !important;
        }

        /* ── Compact unpinned tabs (vertical sidebar) ── */
        .tabbrowser-tab:not([pinned]) {
          min-height: unset !important;
          padding-block: 0 !important;
        }

        .tabbrowser-tab:not([pinned]) .tab-background {
          border-radius: 0 !important;
          width: 100% !important;
        }

        .tabbrowser-tab:not([pinned]) .tab-content {
          padding-block: 2px !important;
          padding-inline: 6px !important;
        }
        .tabbrowser-tab:not([pinned]) .tab-label-container {
          margin: 0 !important;
        }
        .tabbrowser-tab:not([pinned]) .tab-close-button {
          padding: 2px !important;
          width: 16px !important;
          height: 16px !important;
        }
        .tabbrowser-tab:not([pinned]) .tab-icon-image {
          width: 14px !important;
          height: 14px !important;
        }
      '';
    };
  };
}

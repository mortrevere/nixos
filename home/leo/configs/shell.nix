{
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    delta # git diff viewer
  ];

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;

    historySize = 1000000;
    historyFileSize = 1000000;
    historyIgnore = [
      "ls"
      "bg"
      "fg"
      "history"
      "htop"
    ];
    shellOptions = [
      "histappend"
      "cmdhist"
    ];

    shellAliases = {
      ll = "ls -lah";
      gs = "git status";
      rebuild = "sudo nixos-rebuild switch --flake '.?submodules=1#'$(hostname)";
      os-update = "nix flake update --flake '.?submodules=1' && sudo nixos-rebuild switch --flake '.?submodules=1#'$(hostname)";
      sshd-on = "sudo systemctl start sshd";
      sshd-off = "sudo systemctl stop sshd";
      dormir = "echo 'Au RevoiR !' && sleep 2 && shutdown now";
      gp = "git pull --autostash";
      c = "cd ..";
      cconf = "grep -E -v '#|^$'";
      bat = "bat --paging=never";
      cssh = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null";
      watch = "watch "; # trailing space allows alias expansion in watch argument
      fcc = "awk '{print $1}'";
      grep = "grep --color=auto";
      fgrep = "fgrep --color=auto";
      egrep = "egrep --color=auto";
    };

    bashrcExtra = ''
      export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent"
      export PATH="$HOME/.local/bin:$PATH"
      export HISTTIMEFORMAT='%F %T '

      PROMPT_COMMAND='history -a; show_readme_if_changed'

      unalias l 2>/dev/null
      l() {
        find . -iname "*$1*" 2>/dev/null
      }

      LAST_DIR=""
      show_readme_if_changed() {
        local current_dir
        current_dir="$(pwd)"
        if [[ "$current_dir" != "$LAST_DIR" ]]; then
          LAST_DIR="$current_dir"
          if [[ -f "README.md" ]]; then
            bat -pp README.md
          fi
        fi
      }

      jj() {
        local dir
        dir=$(
          find . -type d 2>/dev/null | sed '1d;s#^\./##' | fzf
        ) && builtin cd -- "$dir"
      }

    '';
  };
}

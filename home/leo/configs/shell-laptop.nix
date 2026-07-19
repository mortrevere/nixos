{ config, ... }:

{
  programs.bash = {
    shellAliases = {
      yk-ssh-add = "ssh-add -s $YKCS11_MODULE";
      cdp = "cd ~/platform";
      e = "emacsclient -n";
      ef = "emacsclient -n $(find . -type f | fzf)";
      today = ''nano "$HOME/journal/$(date +%Y-%m-%d).md"'';
      todo = ''nano "$HOME/journal/todo.md"'';
      kclean = "kubectl delete pod --field-selector='status.phase==Failed' && kubectl delete pod --field-selector='status.phase==Succeeded'";
      s = "secret-mgr";
      ss = "rm -f /tmp/rofi; find ${config.home.homeDirectory}/secret | rofi -dmenu | tee /tmp/rofi; ss_choose_action";
    };

    bashrcExtra = ''
      export EDITOR="emacsclient -c -a emacs"
      touch /tmp/rofi

      ppr() {
        local branch remote
        branch=$(git rev-parse --abbrev-ref HEAD)
        remote=$(git remote get-url origin | sed 's/.*github\.com[:/]//;s/\.git$//')
        git push --set-upstream origin "$branch" && \
          firefox --new-tab "https://github.com/$remote/compare/$branch?expand=1"
      }

      ss_choose_action() {
        if cat /tmp/rofi | grep -q 'rc$'; then
          eval "$(cat "$(cat /tmp/rofi)")"
        else
          cat "$(cat /tmp/rofi)" | setclip
        fi
      }

      j() {
        local dir
        dir=$(find ${config.home.homeDirectory}/platform -type d 2>/dev/null | fzf) && builtin cd -- "$dir"
      }
    '';
  };
}

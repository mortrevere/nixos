_:

{
  programs.bash.bashrcExtra = ''
    export PS1="\[\033[38;5;12m\][\[$(tput sgr0)\]\[\033[38;5;9m\]\A\[$(tput sgr0)\]\[\033[38;5;12m\]]\[$(tput sgr0)\]\[\033[38;5;15m\] \u@\h:\[$(tput sgr0)\]\[\033[38;5;27m\]\w\[$(tput sgr0)\]\[\033[38;5;196m\]_>\[$(tput sgr0)\] "
  '';
}

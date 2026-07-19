_:

{
  programs.bash.bashrcExtra = ''
    # Kubectl context/namespace in prompt.
    export PS1="(\$(kctx -c)/\$(kns -c)) \[\033[38;5;12m\][\[$(tput sgr0)\]\[\033[38;5;9m\]\A\[$(tput sgr0)\]\[\033[38;5;12m\]]\[$(tput sgr0)\]\[\033[38;5;15m\] \u:\[$(tput sgr0)\]\[\033[38;5;27m\]\w\[$(tput sgr0)\]\[\033[38;5;15m\]_> \[$(tput sgr0)\]"
  '';
}

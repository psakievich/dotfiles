# Initialize zsh completion, including bash completion compatibility
if [ -n "${ZSH_VERSION:-}" ]; then
  autoload -Uz compinit && compinit
  autoload -Uz bashcompinit && bashcompinit

  # Source bash completion files from spack-managed dirs
  for _comp_dir in ${(s.:.)BASH_COMPLETION_USER_DIR%;}; do
    if [ -d "$_comp_dir" ]; then
      for _comp_file in "$_comp_dir"/*; do
        [ -f "$_comp_file" ] && source "$_comp_file"
      done
    fi
  done
  unset _comp_dir _comp_file
fi

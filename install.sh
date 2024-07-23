#!/bin/bash -l
#
create_symlinks() {
    local current_source_dir=$1
    local current_target_dir=$2

    # Create the target directory if it doesn't exist
    mkdir -p "$current_target_dir"

    # Iterate over all items in the current source directory
    for item in "$current_source_dir"/*; do
        if [ -d "$item" ]; then
            # If the item is a directory, recurse into it
            local subdir_name=$(basename "$item")
            create_symlinks "$item" "$current_target_dir/$subdir_name"
        elif [ -f "$item" ]; then
            # If the item is a file, create a symlink in the target directory
            local filename=$(basename "$item")
            ln -s "$item" "$current_target_dir/$filename"
        fi
    done
}

# Symlink dot-prefixed files
for file in .*
do
  if [ -f "$file" ] && [ "$file" != "." ] && [ "$file" != ".." ] && [ "$file" != ".gitignore" ]; then
    filename=$(basename "$file")
    if [[ "$filename" == "."* ]]; then
      # delete it if it is there (rm stale links)
      rm "${HOME}/$filename"
      ln -s "$(pwd)/$file" "${HOME}/$filename"
      echo "Created Link: ${HOME}/$filename"
    fi
  fi
done

# tmux package manager (TPM)
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# export bash stuff check to see if we've already appended file
dotfileSource=$(grep .dotprofile ${HOME}/.bash_profile)
if [ -z "${dotfileSource}" ]; then
  echo "Appending .bash_profile"
  echo "source ${HOME}/.dotprofile" >> ${HOME}/.bash_profile
fi

# directories
mkdir -p ${HOME}/soft
mkdir -p ${HOME}/.config/nvim
mkdir -p ${HOME}/.config/nvim/lua

# TODO not sure I like this
DOTSPACK=$(pwd)/dotfiles-spack
export SPACK_DISABLE_LOCAL_CONFIG=1

# clone spack and activate it
if [ ! -d "${DOTSPACK}" ]; then
  git clone -c feature.manyFiles=true https://github.com/spack/spack.git ${DOTSPACK}
  ${DOTSPACK}/bin/spack -k bootstrap now
  ${DOTSPACK}/bin/spack config add config:environments_root:$(pwd)/spack_environments
  ${DOTSPACK}/bin/spack mirror add E4S https://cache.e4s.io
  ${DOTSPACK}/bin/spack buildcache keys --install --trust
fi

# copy for nvim files
create_symlinks "$(pwd)/nvim/" "${HOME}/.config/nvim"

# utilize all the work from above in the shell going forward
source ${HOME}/.bash_profile
source ${DOTSPACK}/share/spack/setup-env.sh

# create spack environments to install software
idir=$(pwd)
cd spack_environments
envs=(*)
for env in "${envs[@]}"
do
  spack -e $env install
done
cd ${idir}
  
# install tmux plugins
~/.tmux/plugins/tpm/scripts/update_plugin.sh

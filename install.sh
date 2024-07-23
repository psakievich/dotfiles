#!/bin/bash -l
#

cmd() {
  echo " + $@"
  eval "$@"
}

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

TOPDIR=`pwd`
# Symlink dot-prefixed files
for file in .*
do
  if [ -f "$file" ] && [ "$file" != "." ] && [ "$file" != ".." ] && [ "$file" != ".gitignore" ]; then
    filename=$(basename "$file")
    if [[ "$filename" == "."* ]]; then
      # delete it if it is there (rm stale links)
      if [ -f "${HOME}/$filename" ]; then
	rm "${HOME}/$filename"
      fi
      ln -s "$(pwd)/$file" "${HOME}/$filename"
      echo "Created Link: ${HOME}/$filename"
    fi
  fi
done

# tmux package manager (TPM)
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# export bash stuff check to see if we've already appended file
touch ${HOME}/.bash_profile
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
SPACK_MANAGER=$(pwd)/spack-manager
export SPACK_DISABLE_LOCAL_CONFIG=1

# clone spack and activate it
if [ ! -d "${DOTSPACK}" ]; then
  cmd "git clone -c feature.manyFiles=true https://github.com/spack/spack.git ${DOTSPACK}"
  cmd "${DOTSPACK}/bin/spack bootstrap now"
  cmd "${DOTSPACK}/bin/spack mirror add --scope site develop-developer-tools-manylinux2014 https://binaries.spack.io/develop/develop-developer-tools-manylinux2014"
  cmd "${DOTSPACK}/bin/spack mirror add --scope site develop-ml-darwin-aarch64-mps https://binaries.spack.io/develop/ml-darwin-aarch64-mps"
  cmd "${DOTSPACK}/bin/spack buildcache keys --install --trust"
fi

# copy for nvim files
create_symlinks "$(pwd)/nvim/" "${HOME}/.config/nvim"

# utilize all the work from above in the shell going forward
source ${HOME}/.bash_profile
source ${DOTSPACK}/share/spack/setup-env.sh

if [ ! -d "${SPACK_MANAGER}" ]; then
  git clone https://github.com/sandialabs/spack-manager ${SPACK_MANAGER}
  cd ${SPACK_MANAGER}
  cmd "./install.py --scope site"
  cd ${TOPDIR}
  cmd "spack manager add ${TOPDIR}"

  # define externals at the site level to ensure use across all env's
  cmd "$(spack manager location)/scripts/platform_configure_tool.py --scope site $(spack manager find-machine --config)/externals_to_find.yaml"
fi

# create spack environments to install software
idir=$(pwd)
cd spack_environments
envs=(*)
for env in "${envs[@]}"
do
  echo "Setting up env $env"
  cmd "spack manager create-env -y $env/spack.yaml -n $env"
  cmd "spack -e $env buildcache keys --install --trust"
  cmd "spack -e $env concretize -f"
  cmd "spack -e $env install --cache-only"
done
cd ${idir}
  
load_editor
# install tmux plugins
~/.tmux/plugins/tpm/scripts/update_plugin.sh

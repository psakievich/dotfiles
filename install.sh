#!/bin/bash -l
#
cmd() {
  echo " + $@"
  eval "$@"
}

TOPDIR=`pwd`
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
  git clone -c feature.manyFiles=true https://github.com/spack/spack.git ${DOTSPACK}
  ${DOTSPACK}/bin/spack bootstrap now
  ${DOTSPACK}/spack mirror add --scope site develop-developer-tools-manylinux2014 https://binaries.spack.io/develop/develop-developer-tools-manylinux2014
  ${DOTSPACK}/spack mirror add develop-ml-darwin-aarch64-mps https://binaries.spack.io/develop/ml-darwin-aarch64-mps
  ${DOTSPACK}/spack buildcache keys --install --trust
fi


# links for nvim files
ln -s $(pwd)/vim/init.vim ${HOME}/.config/nvim/init.vim
for file in "$(pwd)"/vim/lua/*
do
  if [ -f "$file" ]; then
    filename=$(basename "$file")
    ln -s "$file" "${HOME}/.config/nvim/lua/$filename"
    echo "Created Link: ${HOME}/.config/nvim/lua/$filename"
  fi
done

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
  cmd "spack -e $env install"
done
cd ${idir}
  
# install tmux plugins
~/.tmux/plugins/tpm/scripts/update_plugin.sh
# neovim packages via packer for now
cmd "nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'"
# Update syntax parsing for languages from TreeSitter
cmd "nvim --headless -c 'TSInstallSync maintaine' -c q"


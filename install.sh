#!/bin/bash -l
#
# export bash stuff check to see if we've already appended file
dotfileSource=$(grep .dotprofile ${HOME}/.bash_profile)

# Symlink dot-prefixed files
for file in .*
do
  if [ -f "$file" ] && [ "$file" != "." ] && [ "$file" != ".." ] && [ "$file" != ".gitignore" ]; then
    filename=$(basename "$file")
    if [[ "$filename" == "."* ]]; then
      #rm "${HOME}/$filename"
      ln -s "$(pwd)/$file" "${HOME}/$filename"
      echo "Created Link: ${HOME}/$filename"
    fi
  fi
done

if [ -z "${dotfileSource}" ]; then
  echo "Appending .bash_profile"
  echo "source ${HOME}/.dotprofile" >> ${HOME}/.bash_profile
fi

# directories
mkdir -p ${HOME}/soft
mkdir -p ${HOME}/.config/nvim
mkdir -p ${HOME}/.config/nvim/lua

DOTSPACK=$(pwd)/dotfiles-spack

# clone spack and activate it
if [ ! -d "${DOTSPACK}" ]; then
  git clone --filter=blob:none -c feature.manyFiles=true https://github.com/spack/spack.git ${DOTSPACK}
  ${DOTSPACK}/bin/spack -k bootstrap now
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

source ${HOME}/.bash_profile
source ${DOTSPACK}/share/spack/setup-env.sh

# create spack environments to install software
idir=$(pwd)
installed=$(spack env ls)
envs=("core" "editor")
for env in "${envs[@]}"
do
if [ "$installed" != *"$env"* ]; then
  spack env create ${env} "${idir}/spack_stuff/${env}.yaml"
fi
  spack env activate ${env}
  spack cd -e
  spack concretize
  spack env depfile -o Makefile
  make -j 10 
  spack env deactivate
done
cd ${idir}
  

# TODO determine what python LSP server still
# python -m pip install --user pyright


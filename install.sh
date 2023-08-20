#!/bin/bash
#
# export bash stuff check to see if we've already appended file
dotfileSource=$(grep .dotprofile ${HOME}/.bash_profile)

# Symlink dot-prefixed files
for file in .*
do
  if [ -f "$file" ] && [ "$file" != "." ] && [ "$file" != ".." ] && [ "$file" != ".gitignore" ]; then
    filename=$(basename "$file")
    if [[ "$filename" == "."* ]]; then
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

# clone spack and activate it
if [ ! -d "${HOME}/soft/system-spack" ]; then
  git clone --filter=blob:none -c feature.manyFiles=true https://github.com/spack/spack.git ${HOME}/soft/system-spack
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

# create spack environments to install software
installed=$(sspack env ls)
envs=("editor" "core")
for env in "${envs[@]}"
do
if [ "$installed" != *"$env}"* ]; then
  sspack env create editor "$(pwd)/spack_stuff/${env}.yaml"
  sspack -e editor concretize
  sspack -e editor install
fi
done
  

# TODO determine what python LSP server still
# python -m pip install --user pyright


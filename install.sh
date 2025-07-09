#!/bin/bash -l

# export bash stuff check to see if we've already appended file
dotfileSource=$(grep .dotprofile ${HOME}/.bash_profile)
if [ -z "${dotfileSource}" ]; then
  echo "Appending .bash_profile"
  echo "source ${HOME}/.dotprofile" >> ${HOME}/.bash_profile
fi

# directories
mkdir -p ${HOME}/soft

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

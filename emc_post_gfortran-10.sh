#!/bin/bash

set -x

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $MYDIR
patch -N -p0 < emc_post_gfortran-10.patch
exit 0

#! /bin/bash
# -------------------------------------------------------------------------- #
# Copyright 2010-2013, Hector Sanjuan, David Rodríguez, Pablo Donaire        #
#                                                                            #
# Licensed under the Apache License, Version 2.0 (the "License"); you may    #
# not use this file except in compliance with the License. You may obtain    #
# a copy of the License at                                                   #
#                                                                            #
# http://www.apache.org/licenses/LICENSE-2.0                                 #
#                                                                            #
# Unless required by applicable law or agreed to in writing, software        #
# distributed under the License is distributed on an "AS IS" BASIS,          #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
# See the License for the specific language governing permissions and        #
# limitations under the License.                                             #
#--------------------------------------------------------------------------- #


function error {
    echo "There was an error performing the installation!"
    exit 1
}

if [ -n "$1" ] ; then
    echo "Usage: ./install.sh"
    echo
    msg="If \$ONE_LOCATION is defined, it will install the files for a  \"self-contained\" OpenNebula installation, under the indicated directory. Otherwise, the installation will be performed in the regular OpenNebula system-wide locations."
    echo $msg | fmt
    echo
    exit 0
fi

if [ -z "$ONE_LOCATION" ] ; then
    echo "Installing system wide..."
    ONE_LIB_DIR="/usr/lib/one"
    ONE_ETC_DIR="/etc/one"
    ONE_VAR_DIR="/var/lib/one"
    ONE_SHARE_DIR="/usr/share/one"
else
    echo "Installing self-contained under $ONE_LOCATION"
    ONE_LIB_DIR=$ONE_LOCATION/lib
    ONE_ETC_DIR=$ONE_LOCATION/etc
    ONE_VAR_DIR=$ONE_LOCATION/var
    ONE_SHARE_DIR=$ONE_LOCATION/share
fi

#LOCATIONS
ONE_VMM_DIR_VBOX=$ONE_VAR_DIR/remotes/vmm/vbox
ONE_IM_DIR_VBOX=$ONE_VAR_DIR/remotes/im/vbox.d
EXAMPLES_VBOX=$ONE_SHARE_DIR/examples/vbox
ONE_ETC_DIR_IM_VBOX=$ONE_ETC_DIR/im_vbox
ONE_ETC_DIR_VMM_VBOX=$ONE_ETC_DIR/vmm_exec
SUNSTONE_USER_PLUGINS=$ONE_LIB_DIR/sunstone/public/js/user-plugins/

#copy remotes in var/
[[ -d $ONE_VMM_DIR_VBOX ]] || mkdir -p $ONE_VMM_DIR_VBOX
cp -v remotes/vmm/vbox/* $ONE_VMM_DIR_VBOX
[[ $? -eq 0 ]] || error

[[ -d $ONE_IM_DIR_VBOX ]] || mkdir -p $ONE_IM_DIR_VBOX
cp -v remotes/im/vbox.d/* $ONE_IM_DIR_VBOX
[[ $? -eq 0 ]] || error

# prepare im_vbox config folder
[[ -d $ONE_ETC_DIR_IM_VBOX ]] || mkdir -p $ONE_ETC_DIR_IM_VBOX

# copy vmm_exec_vbox.conf file with default attributes vbox driver
cp -v etc/vmm_exec/vmm_exec_vbox.conf $ONE_ETC_DIR_VMM_VBOX
[[ $? -eq 0 ]] || error

# copy sunstone plugin
cp -v sunstone/vbox-plugin.js $SUNSTONE_USER_PLUGINS
[[ $? -eq 0 ]] || error

# install examples
[[ -d $EXAMPLES_VBOX ]] || mkdir -p $EXAMPLES_VBOX
cp -v share/examples/vbox/* $EXAMPLES_VBOX
[[ $? -eq 0 ]] || error

echo "Installation completed successfully!"

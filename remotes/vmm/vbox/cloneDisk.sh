#!/bin/bash
# -------------------------------------------------------------------------- #
# Copyright 2010-2011, Hector Sanjuan, David Rodríguez, Pablo Donaire        #
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

disk=$1
rc=0
chmod u+rw "$disk"

# Test valid data file is being cloned
if [ "`file -b \"$disk\"`" = "data" ]
then 
    # Ensure two disks will not have identical UUID
    VBoxManage internalcommands sethduuid "$disk"
    rc=$?
fi
exit $rc
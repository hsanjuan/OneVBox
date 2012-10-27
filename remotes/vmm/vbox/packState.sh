#!/bin/bash
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

domain=$1
vmname=$2
uuid=$3
checkpoint=$4
dir=$(dirname "$domain")

snapshots_folder="$HOME/VirtualBox VMs/$vmname/Snapshots"
last_checkpoint=$(ls -t "$snapshots_folder" | head -1)

saved_domain="$dir/saved_domain.txt"
echo $(basename "$domain") > "$saved_domain"
cp "$snapshots_folder/$last_checkpoint" "$dir/checkpoint.sav"
tar -C $dir -zcf "$checkpoint" "$(basename $domain)" "$(basename $saved_domain)" "checkpoint.sav"
# [[ $? -ne 0 ]] && exit 1
rm "$dir/checkpoint.sav" "$saved_domain"
exit 0

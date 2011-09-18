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

checkpoint_tar=$1
dir=$(dirname $checkpoint_tar)
cd $dir
tar -zxf $(basename $checkpoint_tar)
cat "saved_domain.txt"
rm "$(basename $checkpoint_tar)" "saved_domain.txt"
exit 0

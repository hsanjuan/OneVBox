#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# -------------------------------------------------------------------------- #
# Copyright 2002-2013, OpenNebula Project Leads (OpenNebula.org)             #
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

def print_info(name, value)
    value = "0" if value.nil? or value.to_s.strip.empty?
    puts "#{name}=#{value}"
end

hostinfo = `VBoxManage list hostinfo`
exit 1 if $?.exitstatus != 0

hostinfo.split(/\n/).each do |line|
    if line.match('^Processor count')
        $total_cpu = line.split(":")[1].strip.to_i * 100
    elsif line.match('^Processor\#0 speed')
        $cpu_speed = line.split(":")[1].strip.split(" ")[0]
    end
end


# Rest of the code borrowed from OpenNebula kvm driver
######
#   for everything else, top & proc
#####

NETINTERFACE = "eth1"

top_text=`top -bin2`
exit(-1) if $?.exitstatus!=0

top_text.gsub!(/^top.*^top.*?$/m, "") # Strip first top output

top_text.split(/\n/).each{|line|
    if line.match('^Cpu')
        line[7..-1].split(",").each{|elemento|
            temp = elemento.strip.split("%")
            if temp[1]=="id"
            idle = temp[0]
            $free_cpu = idle.to_f * $total_cpu.to_f / 100
            $used_cpu = $total_cpu.to_f - $free_cpu
                break
            end

        }
    end
}

$total_memory = `free -k|grep "Mem:" | awk '{print $2}'`
tmp=`free -k|grep "buffers\/cache"|awk '{print $3 " " $4}'`.split

$used_memory=tmp[0]
$free_memory=tmp[1]

net_text=`cat /proc/net/dev`
exit(-1) if $?!=0

net_text.split(/\n/).each{|line|
    if line.match("^ *#{NETINTERFACE}")
        arr   = line.split(":")[1].split(" ")
        $netrx = arr[0]
        $nettx = arr[8]
        break
    end
}

print_info("HYPERVISOR","vbox")

print_info("TOTALCPU",$total_cpu)
print_info("CPUSPEED",$cpu_speed)

print_info("TOTALMEMORY",$total_memory)
print_info("USEDMEMORY",$used_memory)
print_info("FREEMEMORY",$free_memory)

print_info("FREECPU",$free_cpu)
print_info("USEDCPU",$used_cpu)

print_info("NETRX",$netrx)
print_info("NETTX",$nettx)

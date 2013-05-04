#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
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

require 'rexml/document'
include REXML

module OneVBoxXMLParser

    def extract_vm_name
        vmid = @xml_root.elements["VMID"]
        return "one-#{vmid.text}" if vmid
        OpenNebula.log_error("Error: could not name the VM")
        return nil
    end

    def create_args
        "--name #{@vmname} --register"
    end

    def modify_args

        #VBoxManage modifyvm VMname ARGS
        modify_args = "";

        memory = @xml_root.elements["MEMORY"]#amount of RAM in MB"
        modify_args << "--memory #{memory.text} " if memory

        vcpu = @xml_root.elements["VCPU"] #number of virtual cpus
        modify_args << "--cpus #{vcpu.text} " if vcpu

        pae = @xml_root.elements["FEATURES/PAE"] #Physical adress extension
        modify_args << (pae.text == "yes"? "--pae on ":"--pae off ") if pae

        acpi = @xml_root.elements["FEATURES/ACPI"] #Advanced configuration and power interface"
        modify_args << (acpi.text == "yes"? "--acpi on ":"--acpi off ") if acpi


        #NIC
        #NETWORK, IP, TARGET, SCRIPT are unsupported

        #loops until all interfaces defined are added.
        niface = 1 #number of interface
        @xml_root.each_element('NIC') do | nic |

            #specifies which host interface the given network interface will use"
            bridge = nic.elements["BRIDGE"]

            if bridge
                modify_args << "--nic#{niface} bridged "
                modify_args << "--bridgeadapter#{niface} #{bridge.text} "
                #normally random address given by VirtualBox
                mac = nic.elements["MAC"]
                modify_args << "--macaddress#{niface} #{(mac.text).delete(":")} " if mac
                niface += 1
            else
                modify_args << "--nic#{niface} nat "
            end

        end

        #INPUT UNSUPPORTED

        #GRAPHICS (VRDP)
        #loops through all the GRAPHICS sections
        #until it finds a "vrdp" one. Then adds the
        #correct arguments and breaks out of loop.
        @xml_root.each_element('GRAPHICS') do | graphics |
            type = graphics.elements["TYPE"]
            if type
                listen = graphics.elements["LISTEN"]#IP to listen
                port = graphics.elements["PORT"]

                case type.text.downcase
                when "vrdp"
                    modify_args << "--vrdp on "
                    modify_args << "--vrdpaddress #{listen.text} " if listen
                    modify_args << (port ? "--vrdpport #{port.text} " : "-- vrdpport default ")

                when "vnc"
                    modify_args << "--vnc on "
                    #modify_args << "--vncaddress #{listen.text} " if listen
                    modify_args << (port ? "--vncport #{port.text} " : "-- vncport default ")
                end
            end
        end


        #RAW
        #Loops through all RAW sections. For those
        #of type "vbox", we add the data arguments.

        @xml_root.each_element('RAW') do | raw |
            if raw.elements["TYPE"] and raw.elements["TYPE"].text == "vbox"
                data = raw.elements["DATA"]
                modify_args << data.text if data
            end
        end

        return "#{@vmname} #{modify_args}" if modify_args.size > 0
        nil
    end

    def start_args
        # Return first graphics section
        @xml_root.each_element('GRAPHICS') do | graphics |
            if graphics.elements["TYPE"]
                type = graphics.elements["TYPE"].text
                case type.downcase
                when "sdl" then return "--type sdl"
                #when "vnc" then return "--type vnc"
                else return "--type headless"
                end
            end
        end
        "--type headless"
    end



    def type_to_medium(type)
        case type.downcase
        when "file" then return "disk"
        when "block" then return "disk"
        when "cdrom" then return "dvd"
        else return "disk"
        end
    end

    #Return an array of strings to close the mediums, arguments of VBoxManage closemedium
    def closemedium_args
        closemedium_args_array = []

        disks().each do |target, type, location, readonly|
            closemedium_args=""
            location << ".iso" if type.downcase() == 'cdrom'
            closemedium_args << "#{type_to_medium(type)} "
            closemedium_args << "#{location} "
            closemedium_args_array << closemedium_args
        end

        return closemedium_args_array
    end

    # Translate the disk target into a valid VBox controller
    def target_to_controller(target)
        disk_type = target[0..1]
        case disk_type
        when "hd" then "ide"
        when "sd" then "sata"
        when "fd" then "floppy"
        else "ide"
        end
    end

    # Returns an array with the controllers that need to be added.
    def controllers_to_add
        toadd = []
        disks().each do |target, type, location, readonly|
            toadd << target_to_controller(target)
        end #each disk

        #do not return duplicate controller names
        return toadd.uniq
    end



    # -- Unused. _device_number_ set to 0.
    # def device_number target
    #   return target[2] - 97
    # end

    # sda -> 0, sdb -> 1, hda -> 0 etc...
    def port_number(target)
        return target[2].ord - 97
    end

    # Convert disk types to VBox format.
    # ===Parameters:
    # * _type_: Disk type in ONE format
    def convert_type(type)
        case type.downcase
        when "file" then return "hdd"
        when "block" then return "hdd"
        when "swap"  then return "hdd"
        when "cdrom" then return "dvddrive"
        else return "hdd"
        end
    end

    # Returns an array of [target, type, path, readonly] of existing disks
    def disks
        basedir = `dirname #{@deployment_file}`.chomp
        disk_locations_array = []
        @xml_root.each_element('DISK|CONTEXT') do |disk|
            begin
                disk_id = disk.elements["DISK_ID"].text
                location = "#{basedir}/disk.#{disk_id}"
                target = disk.elements["TARGET"].text

                # CONTEXT does not have type, but we know it
                if disk.xpath == "/TEMPLATE/CONTEXT"
                    type = 'cdrom'
                else
                    type = disk.elements["TYPE"].text
                end

                readonly = disk.elements["READONLY"]
                readonly = readonly && (readonly.text.downcase == 'yes')
                disk_locations_array << [target, type, location, readonly]
            rescue
                OpenNebula.log_info("Skipping #{location} because: #{$!}")
                next
            end

        end
        return disk_locations_array
    end

    # Returns an array with the necessary arguments to call +storageattach+.
    def storageattach_args
        storageattach_args_array = []
        disks().each do |target, type, location, readonly|
            location << ".iso" if type.downcase == 'cdrom'

            storageattach_args = "#{@vmname}"

            #if these are not defined we cannot call +storageattach+
            controller = target_to_controller(target)
            storageattach_args << " --storagectl ONE-#{controller} "
            storageattach_args << "--port #{port_number(target)} "
            storageattach_args << "--device 0 "
            storageattach_args << "--type #{convert_type(type)} "
            storageattach_args << "--medium #{location} "
            storageattach_args << (readonly ? "--mtype immutable " : "--mtype normal ") if type.downcase != 'cdrom'

            storageattach_args_array << storageattach_args
        end #each_element

        return storageattach_args_array
    end


    # Returns an array with the necessary arguments to call +storagedettach+.
    def storagedettach_args
        storagedettach_args_array = []
        disks().each do |target, type, location, readonly|
            storagedettach_args = "#{@vmname}"
            controller = target_to_controller(target)
            storagedettach_args << " --storagectl ONE-#{controller} "
            storagedettach_args << "--port #{port_number(target)} "
            storagedettach_args << "--device 0 "
            storagedettach_args << "--medium none"
            storagedettach_args_array << storagedettach_args
        end #each_element

        return storagedettach_args_array
    end


    def supports_acpi?
        acpi = @xml_root.elements["FEATURES/ACPI"]
        acpi && (acpi.text == "yes")
    end

end

# Tests parser
# def test
#   open_deployment_xml "deployment.0"

#   puts "**Create args**"
#   puts create_args

#   puts "**Modify args**"
#   puts modify_args

#   puts "**Openmedium**"
#   puts openmedium_args

#   puts "**Closemedium**"
#   puts closemedium_args

#   puts "**Add controllers**"
#   puts controllers_to_add

#   puts "**Attach storage**"
#   puts storageattach_args
# end

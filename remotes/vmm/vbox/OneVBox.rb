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

$: << "#{File.dirname(__FILE__)}/../../"

require 'vboxrc'
require 'OneVBoxXML'
require 'scripts_common'

class OneVBox

    include OneVBoxXMLParser

    attr_reader :vmname, :deployment_file

    def initialize(one_id,dep_file=nil)
        if (!dep_file)
            one_id = one_id.split(":")
            @vmname = one_id[0]
            @deployment_file = one_id[1]
        else
            @deployment_file = dep_file
        end

        begin
            domain=File.new(@deployment_file ,"r")
        rescue
            OpenNebula.log_error("Unable to open domain file:")
            OpenNebula.log_error("File: #{@deployment_file}. vmname: #{@vmname}")
            exit 1
        end

        deployment_xml = Document.new(domain)
        @xml_root = deployment_xml.root
        @vmname ||= extract_vm_name
        OpenNebula.log("VirtualBox VM - Name: #{@vmname}. Deployment file: #{@deployment_file}")
    end

    # Creates the VM with deployment params
    def create
        c_args = create_args
        return nil unless c_args
        OpenNebula.exec_and_log("#{VBOX_CREATE} #{c_args}")
    end


    # Unregister the Virtual Machine with deployment params
    def unregister
        OpenNebula.exec_and_log("#{VBOX_UNREGISTERVM} #{@vmname} --delete")
    end

    # Modifies Virtual Machine with deployment params
    def modify
        m_args = modify_args
        return nil unless m_args #no arguments, its ok
        OpenNebula.exec_and_log("#{VBOX_MODIFYVM} #{m_args}")
    end


    # Deprecated VBOX 4.0
    # Register mediums in VM
    # def open_mediums
    #   rc = 0
    #   disk_number = 1
    #   om_args = openmedium_args
    #   return nil unless om_args
    #   om_args.each do | args |
    #     log "Executing... #{VBOX_OPENMEDIUM} #{args} \n\n"
    #     log `#{VBOX_OPENMEDIUM} #{args}`
    #     rc = $?.exitstatus
    #     break if rc != 0
    #   end
    #   return rc
    # end



    # Make sure disks have unique uuids
    # Make sure they are in a format that can be
    # attached to VirtualBox
    def setup_vbox_disks_formats
        require 'fileutils'

        disks().each do |target, type, path, readonly|
            # If it is a dvddrive vbox needs an ISO extension or it
            # or it will freak out later
            # lets create a symlink
            # and count with it on attach/detach later
            if type == "cdrom"
                OpenNebula.log_info("Symlinking #{path}.iso")
                FileUtils.ln_s(path, "#{path}.iso", :force => true)
                next
            end

            # Try to set unique UUID
            OpenNebula.log_info("Setting unique UUID to #{path}")
            cmd = "#{VBOX_SETHDUUID} #{path}"
            OpenNebula.log_info("Trying: #{cmd}")
            `#{cmd}`
            if $?.exitstatus != 0
                OpenNebula.log_info("Failed to set UUID. Will try to convert it")
                # Failed to set UUID. Assume it is a raw disk and import it
                src = path
                dst = "#{src}.vdi"
                OpenNebula.exec_and_log("#{VBOX_CONVERTFROMRAW} #{src} #{dst}")
                msg = "Replacing #{src} after converting from raw..."
                OpenNebula.log_info(msg)
                FileUtils.mv(dst, src)
            end
        end
        nil
    end


    # Unregister mediums in VM with deployment params
    def close_mediums
        rc=nil
        cm_args = closemedium_args
        return 1 unless cm_args
        cm_args.each do | args |
            rc = OpenNebula.exec_and_log("#{VBOX_CLOSEMEDIUM} #{args}")
            break if rc
        end
        rc
    end


    # Attaches storage controllers in VM with deployment params
    def add_controllers
        rc=nil
        controllers = controllers_to_add()
        return 1 unless controllers

        controllers.each do | controller |
            rc = OpenNebula.exec_and_log("#{VBOX_STORAGECTL} #{@vmname} --name ONE-#{controller} --add #{controller}")
            break if rc
        end
        rc
    end


    # Atttach storage mediums in VM with deployment params
    def storage_attach
        rc=nil
        storageattach_args().each do | sa_args |
            rc = OpenNebula.exec_and_log("#{VBOX_STORAGEATTACH} #{sa_args}")
            break if rc
        end
        rc
    end

    # Dettach storage devices with deployment params
    def storage_dettach
        rc=nil
        storagedettach_args().each do | sd_args |
            rc = OpenNebula.exec_and_log("#{VBOX_STORAGEATTACH} #{sd_args}")
            break if rc
        end
        rc
    end

    # Start a virtual machine with deployment params
    def start
        s_args = start_args()
        OpenNebula.exec_and_log("#{VBOX_STARTVM} #{@vmname} #{s_args}")
    end

    # VM info
    # Missing NET stats and USEDCPU
    # Memory use is the memory assigned to the VM...
    def vminfo
        rc = OpenNebula.log("Running: #{VBOX_SHOWVMINFO} #{@vmname} --machinereadable")
        return rc if rc
        info = `#{VBOX_SHOWVMINFO} #{@vmname} --machinereadable`
        info.split(/\n/).each do | line |
            if line.match('^VMState=')
                state = line.split("=")[1].strip
                if state.include?("running") || state.include?("poweroff")
                    puts "STATE=a"
                elsif state.include?("paused")
                    puts "STATE=p"
                else
                    puts "STATE=-"
                end
            elsif line.match('^memory')
                memory = line.split("=")[1].strip
                puts "USEDMEMORY=#{memory.to_i * 1024}"
            end
        end
        puts info
    end

    #----------------CHANGING VM STATE-------------------#

    # Power off the Virtual Machine
    def power_off
        OpenNebula.log("Running: #{VBOX_SHOWVMINFO} #{@vmname} | grep State")
        state = `#{VBOX_SHOWVMINFO} #{@vmname} | grep State`

        return 0 if state.include?("powered off")

        if state.include?("saved")
            return OpenNebula.exec_and_log("#{VBOX_DISCARDSTATE} #{@vmname}")
        end

        OpenNebula.exec_and_log("#{VBOX_CONTROLVM} #{@vmname} poweroff")
    end

    # Powers off the Virtual Machine
    # via the ACPI power button or the
    # standard way if ACPI is not supported
    def power_off_acpi
        state = `#{VBOX_SHOWVMINFO} #{@vmname} | grep State`
        if supports_acpi? and state.include?("running")
            OpenNebula.exec_and_log("#{VBOX_CONTROLVM} #{@vmname} acpipowerbutton")
        else
            power_off
        end
    end

    #checks if VM is powered off
    def powered_off?
        OpenNebula.log(%&Running #{VBOX_SHOWVMINFO} #{@vmname} | grep State | grep "powered off"&)
        `#{VBOX_SHOWVMINFO} #{@vmname} | grep State | grep "powered off"`
        $?.exitstatus == 0
    end

    # Resets the machine
    def reset
        OpenNebula.exec_and_log("#{VBOX_CONTROLVM} #{@vmname} reset")
    end

    def reboot
        OpenNebula.log_error("Reboot operation not supported")
        nil
    end

    def attach_disk
        OpenNebula.log_error("Attach disk operation not supported")
        nil
    end

    def detach_disk
        OpenNebula.log_error("Detach disk operation not supported")
        nil
    end

    def saved?
        OpenNebula.log(%&Running #{VBOX_SHOWVMINFO} #{@vmname} | grep State | grep "saved"&)
        `#{VBOX_SHOWVMINFO} #{@vmname} | grep State | grep "saved"`
        $?.exitstatus == 0
    end

    def pause
        OpenNebula.exec_and_log("#{VBOX_CONTROLVM} #{@vmname} pause")
    end

    def snapshot_pause
        OpenNebula.exec_and_log("#{VBOX_SNAPSHOT} #{@vmname} take one-snapshot --pause")
    end

    def save_state
        OpenNebula.exec_and_log("#{VBOX_CONTROLVM} #{@vmname} savestate")
    end

    def adopt_state state_file
        OpenNebula.exec_and_log("#{VBOX_ADOPTSTATE} #{@vmname} #{state_file}")
    end

    def get_uuid
        OpenNebula.log("Running #{VBOX_SHOWVMINFO} #{@vmname} | grep \"^UUID\" | cut -d':' -f2 | tr -d \" \"")
        `#{VBOX_SHOWVMINFO} #{@vmname} | grep "^UUID" | cut -d':' -f2 | tr -d " "`.strip
    end
end

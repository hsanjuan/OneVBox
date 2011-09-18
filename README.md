OpenNebula VirtualBox driver plugin (OneVBox)
=============================================

Features
--------
        
The OpenNebula VirtualBox driver (OneVBox) allows the management of hosts and the deployment of virtual machines in OpenNebula using the VirtualBox hypervisor. 
    
OneVBox is formed by an IM_MAD -a serie of remote scripts that are able to monitor the remote hosts- and a VMM_MAD -remotes scripts to manage Virtual Machines-. This scripts typically communicate with by interpreting a XML description of the virtual machines and using the VBoxManage command-line interface to perform the required operations.

Currently, the only common OpenNebula operation which is not supported is Live Migration, due to VirtualBox limitations.


Requirements
------------

 * **OpenNebula 3.0** : Working installation of OpenNebula 3.0 version and, if used, the Sunstone GUI.
 * **VirtualBox 4.x** : The cluster nodes must have a working installation of VirtualBox (currently VirtualBox 4.0 is supported). VirtualBox must be usable by the OpenNebula user (tipically oneadmin), that means this user should pertain to the virtualbox group and the permissions on the VirtualBox executables should be set properly.
 * **Ruby (1.8.7 or 1.9.2)** must be installed in the remote node.
 * **GNU tar** is needed in the remote node to save and migrate Virtual Machines.


Installation
------------

To install the VirtualBox driver run the `install.sh` script provided. This script will copy the necessary files into the OpenNebula installation tree (OpenNebula must be installed beforehand).

If the environmental variable `ONE_LOCATION` is not defined, files will be installed in system-wide mode. Otherwise, they will be installed under `$ONE_LOCATION` self-contained installation.


Driver Configuration
--------------------

In order to enable the one-vbox driver, it is necessary to modify `oned.conf` accordingly. This is achieved by setting the IM_MAD and VM_MAD options as follows: 

    IM_MAD = [
            name       = "im_vbox",
            executable = "one_im_ssh",
            arguments  = "-r 0 -t 15 vbox" ]
	
    VM_MAD = [
            name       = "vmm_vbox",
            executable = "one_vmm_exec",
            arguments  = "vbox",
            default    = "vmm_exec/vmm_exec_vbox.conf",
            type       = "xml" ]

The name of the driver needs to be provided at the time of adding a new host to OpenNebula. For example:

    frontend@opennebula $ onehost create <hostname> im_vbox vmm_vbox tm_ssh

You can find an example oned.conf file in the `share/examples/vbox` folder.


Sunstone plugin configuration
-----------------------------

In order to use the VirtualBox driver in OpenNebula Sunstone you need to enable the Sunstone plugin. This plugin is installed along with the rest of the files. To enable it, you need to modify `$ONE_LOCATION/etc/sunstone-plugins.yaml` or `/etc/one/sunstone-plugins.yaml` adding the following lines:

    - user-plugins/vbox-plugin.js: 
        :group: 
        :ALL: true
        :user: 


Driver files
------------

The one-vbox driver package contains the following files. Note that they are referenced using `$ONE_LOCATION` as the base directory, therefore meaning a self-contained installation of OpenNebula. 

 * `$ONE_LOCATION/etc/vmm_exec/vmm_exec_vbox.conf`: Configuration file to define the default values for the VirtualBox domain definitions.

 * `$ONE_LOCATION/lib/remotes/var/vbox/`: Scripts used to perform the operations on the virtual machines. These files are remotes, meaning they are copied to the remote hosts and executed there.

 * `$ONE_LOCATION/lib/remotes/im/vbox.d/`: Scripts used to fetch information from the remote hosts (memory, cpu use...). These scripts are copied to the remote hosts and executed there.

 * `$ONE_LOCATION/share/examples/vbox/`: Some examples and support files:
    * `oned.conf` : Example OpenNebula configuration file with the VirtualBox drivers enabled.
    * `vbox-test.config` : Schema of the supported attributes in VM template definitions for this driver.

 * `$ONE_LOCATION/lib/sunstone/public/js/user-plugins/vbox-plugin.js`: OpenNebula Sunstone plugin to be able to add VirtualBox hosts and manage VirtualBox virtual machines. 


Authors
-------

This driver is forked from the one-vbox original proyect (http://code.google.com/p/one-vbox), written by Hector Sanjuan, David Rodríguez and Pablo Donaire.

It is maintained by Hector Sanjuan (hsanjuan@opennebula.org).

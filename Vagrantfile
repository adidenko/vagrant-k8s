# -*- mode: ruby -*-
# vi: set ft=ruby :

pool = ENV["VAGRANT_POOL"] || "10.250.0.0/16"

ENV["VAGRANT_DEFAULT_PROVIDER"] = "libvirt"
prefix = pool.gsub(/\.\d+\.\d+\/16$/, "")

$num_instances = (ENV["VAGRANT_VMS"] || 4).to_i
$vm_memory = ENV["VAGRANT_VM_MEMORY"] || (ENV["VAGRANT_DEPLOY_CCP"] && 6144) || 3072
$vm_cpus = ENV["VAGRANT_VM_CPUS"] || 2
$master_memory = 1024
$master_cpus = 1

$user = ENV["USER"]
$public_subnet = prefix.to_s + ".0"
$private_subnet = prefix.to_s + ".1"
$mgmt_cidr = prefix.to_s + ".2.0/24"
oct = pool.split('.')
$neutron_subnet = "172.30.#{oct[1]}"

$instance_name_prefix = "#{$user}-k8s"

# Boxes with libvirt provider support:
#$box = "yk0/ubuntu-xenial" #900M
#$box = "centos/7"
#$box = "nrclark/xenial64-minimal-libvirt"
#$box = "peru/ubuntu-16.04-server-amd64"
$box = "adidenko/ubuntu-1604-k8s"

# Create SSH keys for future lab
system 'bash vagrant-scripts/ssh-keygen.sh'

# Create nodes list for future kargo deployment
nodes=""
(1..$num_instances-1).each do |i|
  ip = "#{$private_subnet}.#{i+10}"
  nodes = "#{nodes}#{ip}\n"
end
File.open("nodes", 'w') { |file| file.write(nodes) }

# Some ansible configuration
ansible_groups = {
  "master" => [],
  "worker" => []
}
ansible_host_vars = {}
ansible_extra_vars = {
  calico_rrs: ENV["CALICO_RRS"] || "",
  kargo_custom_yaml: ENV["KARGO_CUSTOM_YAML"] || "",
  kargo_repo: ENV["KARGO_REPO"] || "",
  kargo_inventory: ENV["KARGO_INVENTORY"] || "nodes_to_inv.py",
  kargo_commit: ENV["KARGO_COMMIT"] || "",
  deploy_ccp: ENV["VAGRANT_DEPLOY_CCP"] || "false",
  deploy_k8s: ENV["VAGRANT_DEPLOY_K8"] || "false",
  deploy_k8s_cmd: ENV["VAGRANT_DEPLOY_K8_CMD"] || "./deploy-k8s.kargo.sh"
}

# Create the lab
Vagrant.configure("2") do |config|
  (0..$num_instances-1).each do |i|
    # First node would be master node
    master = i == 0

    config.ssh.insert_key = false
    vm_name = "%s-%02d" % [$instance_name_prefix, i]
    if master
      ansible_groups["master"] << vm_name
    else
      ansible_groups["worker"] << vm_name
    end

    config.vm.define vm_name do |test_vm|
      test_vm.vm.box = $box
      test_vm.vm.hostname = vm_name

      # Libvirt provider settings
      test_vm.vm.provider :libvirt do |domain|
        domain.uri = "qemu+unix:///system"
        if master
          domain.memory = $master_memory
          domain.cpus = $master_cpus
        else
          domain.memory = $vm_memory
          domain.cpus = $vm_cpus
        end
        domain.driver = "kvm"
        domain.host = "localhost"
        domain.connect_via_ssh = false
        domain.username = $user
        domain.storage_pool_name = "default"
        domain.nic_model_type = "e1000"
        domain.management_network_name = "#{$instance_name_prefix}-mgmt-net"
        domain.management_network_address = $mgmt_cidr
        domain.nested = true
        domain.cpu_mode = "host-passthrough"
        domain.volume_cache = "unsafe"
        domain.disk_bus = "virtio"
        # DISABLED: switched to new box which has 100G / partition
        #domain.storage :file, :type => 'qcow2', :bus => 'virtio', :size => '20G', :device => 'vdb'
      end

      # Networks and interfaces
      ip = "#{$private_subnet}.#{i+10}"
      pub_ip = "#{$public_subnet}.#{i+10}"
      # "public" network with nat forwarding
      test_vm.vm.network :private_network,
        :ip => pub_ip,
        :model_type => "e1000",
        :libvirt__network_name => "#{$instance_name_prefix}-public",
        :libvirt__dhcp_enabled => false,
        :libvirt__forward_mode => "nat"
      # "private" isolated network
      test_vm.vm.network :private_network,
        :ip => ip,
        :model_type => "e1000",
        :libvirt__network_name => "#{$instance_name_prefix}-private",
        :libvirt__dhcp_enabled => false,
        :libvirt__forward_mode => "none"
      # "neutron" isolated network
      test_vm.vm.network :private_network,
        :ip => "#{$neutron_subnet}.#{i+10}",
        :model_type => "e1000",
        :libvirt__network_name => "#{$instance_name_prefix}-neutron",
        :libvirt__dhcp_enabled => false,
        :libvirt__forward_mode => "none"

      # Provisioning
      if ENV["VAGRANT_ANSIBLE"]

        config.vm.provision "file", source: "ssh", destination: "~/ssh"
        config.vm.provision "nodes", type: "file", source: "nodes", destination: "/var/tmp/nodes"
        config.vm.provision "ansible" do |ansible|
          ansible.sudo = true
          ansible.host_vars = ansible_host_vars
          ansible.groups = ansible_groups
          ansible.extra_vars = ansible_extra_vars
          ansible.playbook = "vagrant-scripts/deploy.yaml"
        end

      else

        config.vm.provision "file", source: "ssh", destination: "~/ssh"
        if master
          config.vm.provision "nodes", type: "file", source: "nodes", destination: "/var/tmp/nodes"
          config.vm.provision "bootstrap", type: "shell", path: "vagrant-scripts/provision-master.sh"
        else
          config.vm.provision "bootstrap", type: "shell", path: "vagrant-scripts/provision-node.sh"
        end

      end

    end
  end
end

required_plugins = %w{
  vagrant-librarian-puppet
  vagrant-puppet-install
  vagrant-openstack-provider
}

plugins_to_install = required_plugins.select { |plugin| not Vagrant.has_plugin? plugin }
if not plugins_to_install.empty?
  puts "Installing plugins: #{plugins_to_install.join(' ')}"
  system "vagrant plugin install #{plugins_to_install.join(' ')}"
  exec "vagrant #{ARGV.join(' ')}"
end

# generate a psuedo unique hostname to avoid droplet name/aws tag collisions.
# eg, "jhoblitt-sxn-<os>"
# based on:
# https://stackoverflow.com/questions/88311/how-best-to-generate-a-random-string-in-ruby
def gen_hostname(boxname)
  "#{ENV['USER']}-#{(0...3).map { (65 + rand(26)).chr }.join.downcase}-#{boxname}"
end
def ci_hostname(hostname, provider)
  provider.user_data = <<-EOS
#cloud-config
hostname: #{hostname}
manage_etc_hosts: localhost
  EOS
end

Vagrant.configure('2') do |config|
  config.vm.define 'el6', primary: true do |define|
    hostname = gen_hostname('el6')
    define.vm.hostname = hostname

    define.vm.provider :virtualbox do |provider, override|
      override.vm.box = 'bento/centos-6.7'
    end
    define.vm.provider :digital_ocean do |provider, override|
      provider.image = 'centos-6-7-x64'
    end
    define.vm.provider :aws do |provider, override|
      ci_hostname(hostname, provider)

      # base centos 6 ami
      # provider.ami = 'ami-81d092b1'
      # override.ssh.username = 'root'

      # packer rebuild of base ami
      # provider.ami = 'ami-874b79b7'

      # packer built
      provider.ami = ENV['CENTOS6_AMI'] || 'ami-67e28202'
      provider.region = 'us-east-1'
    end
  end

  config.vm.define 'el7' do |define|
    hostname = gen_hostname('el7')
    define.vm.hostname = hostname

    define.vm.provider :virtualbox do |provider, override|
      override.vm.box = 'bento/centos-7.1'
    end
    define.vm.provider :digital_ocean do |provider, override|
      provider.image = 'centos-7-0-x64'
    end
    define.vm.provider :aws do |provider, override|
      ci_hostname(hostname, provider)

      # base centos 7 ami
      # provider.ami = 'ami-c7d092f7'
      # override.ssh.username = 'centos'

      # packer build of base ami
      # provider.ami = 'ami-29576419'

      # packer built
      provider.ami = ENV['CENTOS7_AMI'] || 'ami-ffe3839a'
      provider.region = 'us-east-1'
    end
    define.vm.provider :openstack do |provider, override|
      #config.vm.define 'jmattvagrant', primary: true do |define|
      define.vm.box       = 'openstack-test'
#      define.ssh.username = 'vagrant'
      config.ssh.username = 'vagrant'
#      override.ssh.username = 'vagrant'
      define.vm.provision "shell", inline: "true" # work around for https://github.com/ggiamarchi/vagrant-openstack-provider/issues/240
      define.ssh.pty = true # recommended in docs for CentOS

      #define.vm.provider :openstack do |os|
      provider.openstack_auth_url = ENV['OS_AUTH_URL']
      provider.username           = ENV['OS_USERNAME']
      provider.password           = ENV['OS_PASSWORD']
      provider.tenant_name        = ENV['OS_PROJECT_NAME']
      provider.flavor             = ENV['OS_FLAVOR_NAME'] || 'm1.medium'
      provider.image              = ENV['OS_IMAGE_NAME'] || 'centos-7-vagrant-1446594702'
      provider.floating_ip_pool   = 'ext-net'
      provider.security_groups    = ['default', 'remote SSH', 'remote mosh']
      provider.networks           = ['fc77a88d-a9fb-47bb-a65d-39d1be7a7174']
    end
  end

  config.vm.define 'f22' do |define|
    hostname = gen_hostname('f22')
    define.vm.hostname = hostname

    define.vm.provider :virtualbox do |provider, override|
      override.vm.box = 'bento/fedora-22'
    end
    define.vm.provider :digital_ocean do |provider, override|
      provider.image = 'fedora-22-x64'
    end

    define.vm.provider :aws do |provider, override|
      ci_hostname(hostname, provider)

      # f22 official
      # https://getfedora.org/cloud/download/
      #provider.ami = 'ami-81698dea'

      provider.ami = 'ami-47cda222'
      provider.region = 'us-east-1'
    end
  end

  # setup the remote repo needed to install a current version of puppet
  config.puppet_install.puppet_version = '3.8.2'

  config.vm.provision :puppet do |puppet|
    puppet.manifests_path = "manifests"
    puppet.module_path = "modules"
    puppet.manifest_file = "init.pp"
    puppet.options = [
     '--verbose',
     '--report',
     '--show_diff',
     '--pluginsync',
     '--disable_warnings=deprecations',
    ]
    puppet.facter = {
      'lsst_stack_user' => 'vagrant',
    }
  end

  config.vm.provider :virtualbox do |provider, override|
    provider.memory = 2048
    provider.cpus = 2
  end

  config.vm.provider :digital_ocean do |provider, override|
    override.vm.box = 'digital_ocean'
    override.vm.box_url = 'https://github.com/smdahlen/vagrant-digitalocean/raw/master/box/digital_ocean.box'
    # it appears to blow up if you set the username to vagrant...
    override.ssh.username = 'lsstsw'
    override.ssh.private_key_path = SSH_PRIVATE_KEY_PATH
    override.vm.synced_folder '.', '/vagrant', :disabled => true

    provider.token = DO_API_TOKEN
    provider.region = 'nyc3'
    provider.size = '16gb'
    provider.setup = true
    provider.ssh_key_name = SSH_PUBLIC_KEY_NAME
  end

  config.vm.provider :aws do |provider, override|
    override.vm.box = 'aws'
    override.vm.box_url = "https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box"
    # http://blog.damore.it/2015/01/aws-vagrant-no-host-ip-was-given-to.html
    override.nfs.functional = false
    override.vm.synced_folder '.', '/vagrant', :disabled => true
    #override.vm.synced_folder 'hieradata/', '/tmp/vagrant-puppet/hieradata'
    #override.ssh.private_key_path = "#{Dir.home}/.sqre/ssh/id_rsa_sqre"
    override.ssh.private_key_path = "#{Dir.home}/.vagrant.d/insecure_private_key"
    provider.keypair_name = "vagrant"
    provider.access_key_id = ENV['AWS_ACCESS_KEY_ID']
    provider.secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
    provider.region = ENV['AWS_DEFAULT_REGION']
    if ENV['AWS_SECURITY_GROUPS']
      provider.security_groups = ENV['AWS_SECURITY_GROUPS'].strip.split(/\s+/)
    else
      provider.security_groups = ['sshonly']
    end
    if ENV['AWS_SUBNET_ID']
      provider.subnet_id = ENV['AWS_SUBNET_ID']
      # assume we don't have an accessible public IP
      provider.ssh_host_attribute = :private_ip_address
    end
    provider.instance_type = 'c4.2xlarge'
    provider.ebs_optimized = true
    provider.block_device_mapping = [{
      'DeviceName'              => '/dev/sda1',
      'Ebs.VolumeSize'          => 40,
      'Ebs.VolumeType'          => 'gp2',
      'Ebs.DeleteOnTermination' => 'true',
    }]
    provider.tags = { 'Name' => "stackbuild" }
    # attempt to stop hitting aws' RequestLimitExceeded - default is 2
    #provider.instance_check_interval = 10
  end

  if Vagrant.has_plugin?('vagrant-librarian-puppet')
    config.librarian_puppet.placeholder_filename = ".gitkeep"
  end

  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.scope = :box
  end

  # based on:
  # https://github.com/mitchellh/vagrant/issues/1753#issuecomment-53970750
  #if ARGV[0] == 'ssh'
  #  config.ssh.username = 'lsstsw'
  #  config.ssh.private_key_path = SSH_PRIVATE_KEY_PATH
  #end
end

# concept from:
# http://ryan.muller.io/devops/2014/03/26/chef-vagrant-and-digital-ocean.html
SANDBOX_GROUP = ENV['SQRE_SANDBOX_GROUP'] || 'sqreuser'
if File.exist? "#{Dir.home}/.#{SANDBOX_GROUP}"
  root="#{Dir.home}/.#{SANDBOX_GROUP}"
  do_c = "#{root}/do/credentials.rb"
  aws_c = "#{root}/aws/credentials.rb"
  load do_c if File.exists? do_c
  load aws_c if File.exists? aws_c
  SSH_PRIVATE_KEY_PATH="#{root}/ssh/id_rsa_#{SANDBOX_GROUP}"
  SSH_PUBLIC_KEY_NAME=SANDBOX_GROUP
else
  if ENV['DO_API_TOKEN']
    DO_API_TOKEN = ENV['DO_API_TOKEN']
  else
    DO_API_TOKEN = '<api key...>'
  end
  SSH_PRIVATE_KEY_PATH="#{Dir.home}/.vagrant.d/insecure_private_key"
  SSH_PUBLIC_KEY_NAME='vagrant'
end

# -*- mode: ruby -*-
# vi: set ft=ruby :

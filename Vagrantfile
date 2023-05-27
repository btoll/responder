# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
    config.vm.box = "ubuntu/focal64"

    config.vm.provision "shell", inline: <<-SHELL
        apt-get update
        apt-get install -y ruby-full pry
    SHELL
end



require "yaml"
vagrant_root = File.dirname(File.expand_path(__FILE__))
settings = YAML.load_file "#{vagrant_root}/settings.yaml"

NUM_WORKER_NODES = settings["nodes"]["workers"]["count"]

Vagrant.configure("2") do |config|
  config.vm.provision "file", source: "settings.yaml", destination: "/vagrant/settings.yaml"
  config.trigger.before :provisioner_run, type: :hook do |trigger|
    trigger.ruby do |env, machine|
      # Build a hostname -> IP map for every running VM.
      hosts_map = {}
      env.machine_names.each do |name|
        m = env.machine(name, machine.provider_name)
        ip = `utmctl ip-address #{m.id} 2>/dev/null`.lines.first&.strip
        env.ui.info("[hosts] Checked #{name} #{m.state.id} IP: #{ip.inspect}")
        next unless m.state.id == :started
        if ip.nil? || ip.empty?
          env.ui.warn("[hosts] Could not get IP for #{name}, skipping")
          next
        end
        env.ui.info("[hosts] #{name} => #{ip}")
        hosts_map[name.to_s] = ip
      end

      next if hosts_map.empty?

      # Push the full map to every running VM.
      hosts_map.each_key do |target_name|
        m = env.machine(target_name.to_sym, machine.provider_name)
        hosts_map.each do |hostname, ip|
          begin
            m.communicate.sudo("sed -i '/[[:space:]]#{hostname}$/d' /etc/hosts && echo '#{ip} #{hostname}' >> /etc/hosts")
          rescue => e
            env.ui.warn("[hosts] Could not update #{target_name} with #{hostname}: #{e.message}")
          end
        end
        env.ui.info("[hosts] #{target_name} /etc/hosts up to date")
      end
    end
  end

  config.vm.box = settings["software"]["box"]

  config.vm.box_check_update = true

  config.vm.define "controlplane" do |controlplane|
    controlplane.vm.hostname = "controlplane"
    if settings["shared_folders"]
      settings["shared_folders"].each do |shared_folder|
        controlplane.vm.synced_folder shared_folder["host_path"], shared_folder["vm_path"]
      end
    end
    controlplane.vm.provider "utm" do |vb|
        vb.cpus = settings["nodes"]["control"]["cpu"]
        vb.memory = settings["nodes"]["control"]["memory"]
    end
    controlplane.vm.provision "shell",
      env: {
        "DNS_SERVERS" => settings["network"]["dns_servers"].join(" "),
        "ENVIRONMENT" => settings["environment"],
        "KUBERNETES_VERSION" => settings["software"]["kubernetes"],
        "KUBERNETES_VERSION_SHORT" => settings["software"]["kubernetes"][0..3],
        "OS" => settings["software"]["os"],
      },
      path: "scripts/common.sh"
    controlplane.vm.provision "shell",
      env: {
        "CALICO_VERSION" => settings["software"]["calico"],
        "CONTROL_IP" => settings["network"]["control_ip"],
        "POD_CIDR" => settings["network"]["pod_cidr"],
        "SERVICE_CIDR" => settings["network"]["service_cidr"]
      },
      path: "scripts/controlplane.sh"
  end

  (1..NUM_WORKER_NODES).each do |i|

    config.vm.define "node0#{i}" do |node|
      # node.communicate.sudo("scp user@source_ip:/src /dest")
      node.vm.hostname = "node0#{i}"
      if settings["shared_folders"]
        settings["shared_folders"].each do |shared_folder|
          node.vm.synced_folder shared_folder["host_path"], shared_folder["vm_path"]
        end
      end
      node.vm.provider "utm" do |vb|
          vb.cpus = settings["nodes"]["workers"]["cpu"]
          vb.memory = settings["nodes"]["workers"]["memory"]
      end
      node.vm.provision "shell",
        env: {
          "DNS_SERVERS" => settings["network"]["dns_servers"].join(" "),
          "ENVIRONMENT" => settings["environment"],
          "KUBERNETES_VERSION" => settings["software"]["kubernetes"],
          "KUBERNETES_VERSION_SHORT" => settings["software"]["kubernetes"][0..3],
          "OS" => settings["software"]["os"],
        },
        path: "scripts/common.sh"
      node.vm.provision "shell", path: "scripts/node.sh"

      # Only install the dashboard after provisioning the last worker (and when enabled).
      if i == NUM_WORKER_NODES and settings["software"]["dashboard"] and settings["software"]["dashboard"] != ""
        node.vm.provision "shell", path: "scripts/dashboard.sh"
      end
    end

  end
end 

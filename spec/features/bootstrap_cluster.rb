require "spec_helper"
require 'yaml'

feature "Boostrap cluster" do

  before do
    # In case something went wrong and we have leftovers
    puts "Cleaning up running minions"
    cleanup_environment
    cleanup_minions

    puts "Starting environment"
    start_environment
    puts "Registering user"
    register
    puts "Setting up velum"
    configure
    puts "Spawning minions"
    spawn_minions 2
  end

  after do |example|
    dump_container_logs if example.exception
    unless ENV["KEEP"]
      cleanup_environment
      cleanup_minions
    end
  end

  scenario "it creates a kubernetes cluster" do

    dashboard_container = Container.new("velum-dashboard")
    salt_master_container = Container.new("salt-master")
    # Wait until all minions are pending
    command = "salt-key --list all --out yaml"
    loop_with_timeout(timeout: 15, interval: 1) do
      raw = salt_master_container.command(command)[:stdout]
      minions = YAML.load raw
      minions["minions_pre"].length == 2
    end
    visit "/setup/discovery"
    # Accept all nodes until all of them have been accepted
    command = "salt-key --list all --out yaml"
    loop_with_timeout(timeout: 60, interval: 1) do
      find("#accept-all").click
      raw = salt_master_container.command(command)[:stdout]
      minions = YAML.load raw
      minions["minions_pre"].empty?
    end
    # Wait until Minions are registered
    command = "entrypoint.sh rails runner 'ActiveRecord::Base.logger=nil; puts Minion.count'"
    minions_registered = loop_with_timeout(timeout: 35, interval: 1) do
      dashboard_container.command(command)[:stdout].to_i == 2
    end
    expect(minions_registered).to be(true)
    visit "/setup/discovery"

    # They should also appear in the UI
    expect(page).to have_content("minion0.k8s.local")
    expect(page).to have_content("minion1.k8s.local")

    # Select master minion
    find(".check-all").click
    within("div.nodes-container") do
      first("input[type='radio']").click
    end
    click_on 'Bootstrap cluster'

    # a modal with a warning will appear as we only have 2 nodes
    expect(page).to have_content("Cluster is too small")
    click_button "Proceed anyway"

    # Wait until orchestration is complete
    query = "Minion.where(highstate: [Minion.highstates[:applied], Minion.highstates[:failed]]).count"
    command = "entrypoint.sh rails runner 'ActiveRecord::Base.logger=nil; puts #{query}'"
    orchestration_completed = loop_with_timeout(timeout: 1500, interval: 1) do
      dashboard_container.command(command)[:stdout].to_i == 2
    end
    expect(orchestration_completed).to be(true)

    # All Minions should have been applied the highstate successfully
    query = "Minion.where(highstate: Minion.highstates[:applied]).count"
    command = "entrypoint.sh rails runner 'ActiveRecord::Base.logger=nil; puts #{query}'"
    expect(dashboard_container.command(command)[:stdout].to_i).to eq(2)

    minions = Minion.all
    applied_roles = minions.map(&:roles).flatten
    expect(applied_roles.sort).to eq(["kube-master", "kube-minion"])

    if minions.first.roles.first == "kube-master"
      master, minion = minions
    else
      minion, master = minions
    end

    # Check that the expected programs are running on each node.
    expected_services = ["/usr/sbin/etcd", "salt-minion", "hyperkube apiserver",
                         "hyperkube scheduler", "hyperkube controller-manager"]
    running_services = []
    expected_services.each { |p| running_services << p if master.running?(p) }
    expect(running_services).to eq(expected_services)

    expected_services = ["/usr/sbin/etcd", "salt-minion", "flannel", "docker",
                         "containerd", "hyperkube proxy", "hyperkube kubelet"]
    running_services = []
    expected_services.each { |p| running_services << p if minion.running?(p) }
    expect(running_services).to eq(expected_services)

    # Sanity checks on the Kubernetes cluster.
    out = master.command("kubectl cluster-info dump --output-directory=/tmp/cluster_info")[:stdout]
    expect(out).to eq "Cluster info dumped to /tmp/cluster_info"

    # The pause image is there.
    # TODO: depending whether it's opensuse or microos, this image will be available or not
    #
    # found = false
    # nodes["items"].first["status"]["images"].each do |images|
    #   images["names"].each { |name| found = true if name == "suse/pause:latest" }
    # end
    # expect(found).to be_truthy

    # Now let's check for etcd
    flags = '--ca-file /etc/pki/trust/anchors/SUSE_CaaSP_CA.crt'
    flags += ' --key-file /etc/pki/minion.key'
    flags += ' --cert-file /etc/pki/minion.crt'
    flags += ' --endpoints="https://127.0.0.1:2379"'
    out = master.command("etcdctl #{flags} cluster-health")[:stdout]
    expect(out.include?("got healthy result")).to be_truthy

    # Download kubeconfig and try to use it
    # http://stackoverflow.com/a/17111206
    data = page.evaluate_script("\
      function() {
        var url = window.location.protocol + '//' + window.location.host + '/kubectl-config';\
        var xhr = new XMLHttpRequest();\
        xhr.open('GET', url, false);\
        xhr.send(null);\
        return xhr.responseText;\
      }()
    ")

    File.write("kubeconfig", data)
    # Replace the master minion hostname with its ip in the kubeconfig file
    # because we have no DNS running to resolve the hostname.
    master_id = YAML.load(master.command("salt-call grains.get fqdn")[:stdout])["local"]
    system_command(command: "sed -i -- 's/server: https:\\\/\\\/.*:6443/server: https:\\\/\\\/#{master.ip}:6443/g' kubeconfig")
    get_nodes_result =
      system_command(command: "kubectl --kubeconfig=kubeconfig get nodes -o go-template='{{ range .items }}{{ range .status.conditions }}{{ if eq .reason \"KubeletReady\" }}{{ .status }}{{ end }}{{ end }}{{ end }}'")[:stdout]

    expect(get_nodes_result).to eq("True")
  end
end

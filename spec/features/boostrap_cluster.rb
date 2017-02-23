require "spec_helper"

feature "Boostrap cluster" do
  before do
    # In case something went wrong and we have leftovers
    puts "Cleaning up running minions"
    cleanup_minions

    puts "Starting environment"
    start_environment
    login
    puts "Spawning minions"
    spawn_minions 2
  end

  after do
    cleanup_environment
    cleanup_minions
  end

  scenario "it runs creates a kubernetes cluster" do
    visit "/nodes/index"
    expect(page).to have_content('minion0.k8s.local')
    click_on 'Bootstrap cluster'

    minions = Minion.all
    applied_roles = minions.map(&:roles).flatten
    expect(applied_roles.sort).to eq(["kube-master", "kube-minion"])

    if minions.first.roles.first == "kube-master"
      master, minion = minions
    else
      minion, master = minions
    end

    # Check that the expected programs are running on each node.

    ["etcd", "salt-minion", "kube-apiserver", "kube-scheduler", "kube-controller"]. each do |p|
      expect(master.running?(p)).to be_truthy
    end

    ["etcd", "salt-minion", "flannel", "docker", "containerd", "kube-proxy", "kubelet"]. each do |p|
      expect(minion.running?(p)).to be_truthy
    end

    ##
    # Sanity checks on the Kubernetes cluster.

    out = master.command("kubectl cluster-info dump --output-directory=/opt/info")[:stdout]
    expect(out).to eq "Cluster info dumped to /opt/info"

    # One minion named minion0
    nodes = JSON.parse(master.command("cat /opt/info/nodes.json")[:stdout])
    expect(nodes["items"].first["metadata"]["name"]).to eq "minion0"

    # The pause image is there.
    found = false
    info["items"].first["status"]["images"].each do |images|
      images["names"].each { |name| found = true if name == "suse/pause:latest" }
    end
    expect(found).to be_truthy

    # Now let's check for etcd

    flags = '--key-file=/etc/pki/minion.key --cert-file=/etc/pki/minion.crt ' \
            '--ca-file=/var/lib/k8s-ca-certificates/cluster_ca.crt ' \
            '--endpoints="https://minion1.k8s.local:2379,https://minion0.k8s.local:2379"'
    out = master.command("etcdctl #{flags} cluster-health")[:stdout]
    expect(out.include?("got healthy result")).to be_truthy
  end
end

require "spec_helper"
require 'yaml'

feature "Boostrap cluster" do

  let(:node_number) { ENV.fetch("NODE_NUMBER", 2).to_i }
  let(:hostnames) { ENV.fetch("HOSTNAMES", node_number.times.map { |n| "minion#{n}.k8s.local" }.join(",")).split(",") }
  let(:dashboard_container) { Container.new("velum-dashboard") }
  let(:salt_master_container) { Container.new("salt-master") }
  let(:list_salt_keys_command) { "salt-key --list all --out yaml" }
  let(:minion_count_command) { "entrypoint.sh bundle exec rails runner \'ActiveRecord::Base.logger=nil; puts Minion.count\'" }
  let(:orchestration_query) { "Minion.where(highstate: [Minion.highstates[:applied], Minion.highstates[:failed]]).count" }
  let(:orchestration_check_command) { "entrypoint.sh bundle exec rails runner \'ActiveRecord::Base.logger=nil; puts #{orchestration_query}\'" }
  let(:highstate_applied_query) { "Minion.where(highstate: Minion.highstates[:applied]).count" }
  let(:highstate_applied_command) { "entrypoint.sh bundle exec rails runner \'ActiveRecord::Base.logger=nil; puts #{highstate_applied_query}\'" }

  before(:each) do
    unless self.inspect.include? "User registers"
      login
    end
  end

  after(:each) do
    # this can be dropped after velum/puma can handle multiple concurrent connections
    Capybara.reset_session!
  end

  scenario "User registers" do
    register
  end

  scenario "User configures the cluster" do
    configure
  end

  scenario "User accepts all minions" do
    visit "/setup/discovery"

    puts ">>> Wait until all minions are pending to be accepted"
    loop_with_timeout(timeout: 60, interval: 5) do
      minions = YAML.load(salt_master_container.command(list_salt_keys_command)[:stdout])
      minions["minions_pre"].length == node_number
    end
    puts ">>> All minions are pending to be accepted"

    puts ">>> Click to accept all minion keys"
    loop_with_timeout(timeout: 120, interval: 20) do
      break if page.has_content?("#{node_number} nodes found")
      find("#accept-all").click rescue false
    end

    puts ">>> Wait until Minion keys are accepted by salt"
    loop_with_timeout(timeout: 60, interval: 5) do
      raw = salt_master_container.command(list_salt_keys_command)[:stdout]
      minions = YAML.load raw
      minions["minions_pre"].empty?
    end
    puts ">>> Minion keys accepted by salt"

    puts ">>> Waiting until Minions are accepted in Velum"
    minions_accepted = loop_with_timeout(timeout: 120, interval: 5) do
      !page.has_content?("Acceptance in progress") && first("h3").text == "#{node_number} nodes found"
    end
    expect(minions_accepted).to be(true)
    puts ">>> Minions accepted in Velum"

    puts ">>> Wait until Minions are registered in the Velum database"
    minions_registered = loop_with_timeout(timeout: 120, interval: 5) do
      dashboard_container.command(minion_count_command)[:stdout].to_i == node_number
    end
    expect(minions_registered).to be(true)
    puts ">>> Minions registered in the Velum database"

    # They should also appear in the UI
    hostnames.each do |hostname|
      expect(page).to have_content(hostname)
    end
  end

  scenario "User selects a master and bootstraps the cluster" do
    visit "/setup/discovery"

    puts ">>> Selecting all minions"
    find(".check-all").click
    puts ">>> All minions selected"

    puts ">>> Selecting master minion"
    within("div.nodes-container") do
      first("input[type='radio']").click
    end
    puts ">>> Master minion selected"

    puts ">>> Bootstrapping cluster"
    click_on 'Bootstrap cluster'

    if node_number < 3
      # a modal with a warning will appear as we only have #{node_number} nodes
      expect(page).to have_content("Cluster is too small")
      click_button "Proceed anyway"
    end
    puts ">>> Cluster bootstrapped"

    puts ">>> Wait until orchestration is complete"
    orchestration_completed = loop_with_timeout(timeout: 1500, interval: 5) do
      dashboard_container.command(orchestration_check_command)[:stdout].to_i == node_number
    end
    expect(orchestration_completed).to be(true)
    puts ">>> Orchestration completed"

    # All Minions should have been applied the highstate successfully
    puts ">>> Checking highstate"
    expect(dashboard_container.command(highstate_applied_command)[:stdout].to_i).to eq(node_number)
  end
end

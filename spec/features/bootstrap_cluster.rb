require "spec_helper"
require 'yaml'

feature "Boostrap cluster" do

  before do
    puts "Registering user"
    register
    puts "Setting up velum"
    configure
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
    command = "entrypoint.sh bundle exec rails runner \'ActiveRecord::Base.logger=nil; puts Minion.count\'"
    minions_registered = loop_with_timeout(timeout: 120, interval: 1) do
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
    command = "entrypoint.sh bundle exec rails runner \'ActiveRecord::Base.logger=nil; puts #{query}\'"
    orchestration_completed = loop_with_timeout(timeout: 1500, interval: 1) do
      dashboard_container.command(command)[:stdout].to_i == 2
    end
    expect(orchestration_completed).to be(true)

    # All Minions should have been applied the highstate successfully
    query = "Minion.where(highstate: Minion.highstates[:applied]).count"
    command = "entrypoint.sh bundle exec rails runner \'ActiveRecord::Base.logger=nil; puts #{query}\'"
    expect(dashboard_container.command(command)[:stdout].to_i).to eq(2)
  end
end

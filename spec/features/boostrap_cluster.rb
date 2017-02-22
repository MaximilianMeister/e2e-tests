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
    expect(applied_roles.sort).to eq("master", "minion")
    # TODO: we need assertions for successful orchestration
  end
end

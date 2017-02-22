# frozen_string_literal: true
# A module containing helper methods to create a testing environment
# for end to end tests.
module Helpers
  # Spawns salt-minions which connect to velum.
  # The minion is a Virtual Machine which we build using terraform.
  def spawn_minions(number_of_minions)
    `#{File.join(scripts_path, "spawn_minions")} #{number_of_minions.to_i}`
  end

  def cleanup_minions
    `#{File.join(scripts_path, "cleanup_minions")}`
  end

  # Runs the script that creates the testing environment
  def start_environment
    `#{File.join(scripts_path, "start_environment")}`
  end

  def cleanup_environment
    `#{File.join(scripts_path, "cleanup_environment")}`
  end

  def scripts_path
    script = File.join(
      File.dirname(File.dirname(File.dirname(__FILE__))),
      "scripts",
    )
  end

  private

  # This returns the server's host in tests with "js: true"
  def server_host
    Capybara.current_session.server.try(:host)
  end

  # This returns the server's port in tests with "js: true"
  def server_port
    Capybara.current_session.server.try(:port)
  end

  def login
    visit "/users/sign_in"
    fill_in "user_email", with: "test@test.com"
    fill_in "user_password", with: "password"
    click_on "Log in"
  end
end

RSpec.configure { |config| config.include Helpers, type: :feature }

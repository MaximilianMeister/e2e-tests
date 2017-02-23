# A module containing helper methods to create a testing environment
# for end to end tests.
module Helpers
  # Spawns salt-minions which connect to velum.
  # The minion is a Virtual Machine which we build using terraform.
  def spawn_minions(number_of_minions, verbose: false)
    system_command(
      command: "#{File.join(scripts_path, "spawn_minions")} #{number_of_minions.to_i}",
      verbose: verbose
    )
  end

  def cleanup_minions(verbose: false)
    system_command(command: "#{File.join(scripts_path, "cleanup_minions")}", verbose: verbose)
  end

  # Runs the script that creates the testing environment
  def start_environment(verbose: false)
    system_command(command: "#{File.join(scripts_path, "start_environment")}", verbose: verbose)
  end

  def cleanup_environment(verbose: false)
    system_command(
      command: "#{File.join(scripts_path, "cleanup_environment")}",
      verbose: verbose
    )
  end

  def scripts_path
    script = File.join(
      File.dirname(File.dirname(File.dirname(__FILE__))),
      "scripts",
    )
  end

  # https://nickcharlton.net/posts/ruby-subprocesses-with-stdout-stderr-streams.html
  # see: http://stackoverflow.com/a/1162850/83386
  def system_command(command:, verbose: false)
    start_time_at = Time.now
    stdout_data = ''
    stderr_data = ''
    exit_code = nil
    threads = []

    Open3.popen3(command) do |stdin, stdout, stderr, thread|
      [[stdout_data, stdout], [stderr_data, stderr]].each do |store_var, stream|
        threads << Thread.new do
          until (line = stream.gets).nil? do
            store_var << line # append new lines
            (verbose || ENV["VERBOSE"]) && puts(line)
          end
        end
      end

      exit_code = thread.value.exitstatus

      # The main thread (the command) is done so any commands binding the stdout
      # or stderr should not prevent this method from returning.
      # Give a fair timeout in case there is some last data on a stream which
      # the thread did not have the time to read.
      begin
        Timeout::timeout(1) { threads.map(&:join) }
      rescue Timeout::Error
        threads.each(&:exit)
      end
    end

    { stdout: stdout_data.strip,
      stderr: stderr_data.strip,
      exit_code: exit_code,
      duration: Time.now - start_time_at }
  end

  # This method can be used to wait for something to happen.
  # E.g. Wait for a record to appear in the velum-dashboard database.
  # timeout is the number of seconds before the loop is exited
  # inteval is the number of seconds to wait before next invocation of the block
  # block is the code that must return true to exit the loop
  #
  # The method return false if the timeout is reached or the block never returns
  # true.
  def loop_with_timeout(timeout:, interval: 1, &block)
    start_time = Time.now
    loop do
      return false if Time.now - start_time > timeout
      return true if yield
    end
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

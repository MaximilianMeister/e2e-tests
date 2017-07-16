# A module containing helper methods to create a testing environment
# for end to end tests.
module Helpers
  # https://nickcharlton.net/posts/ruby-subprocesses-with-stdout-stderr-streams.html
  # see: http://stackoverflow.com/a/1162850/83386
  def system_command(command:, verbose: false, host: "localhost", ssh_key_path: nil)
    start_time_at = Time.now
    stdout_data = ''
    stderr_data = ''
    exit_code = nil
    threads = []
    ssh_flags = "-q -o 'StrictHostKeyChecking no' -o UserKnownHostsFile=/dev/null"
    ssh_key_path = environment["sshKey"] || ssh_key_path
    ssh_flags << " -i #{ssh_key_path}" if ssh_key_path
    # echo and | are necessary not to lose quotes of nested command arguments
    command = "echo \"#{command}\" | ssh #{ssh_flags} root@#{host}" unless host == "localhost"

    Open3.popen3(ENV, command) do |stdin, stdout, stderr, thread|
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
  def wait_for(timeout:, interval: 1, &block)
    start_time = Time.now
    loop do
      fail("Timed out") if Time.now - start_time > timeout
      return true if yield == true
      sleep interval
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
    puts ">>> User logs in"
    visit "/users/sign_in"
    fill_in "user_email", with: "test@test.com"
    fill_in "user_password", with: "password"
    click_on "Log in"
    puts "<<< User logged in"
  end

  def register
    puts ">>> Registering user"
    visit "/users/sign_up"
    fill_in "user_email", with: "test@test.com"
    fill_in "user_password", with: "password"
    fill_in "user_password_confirmation", with: "password"
    click_on "Create Admin"
    puts "<<< User registered"
  end

  def default_interface
    `awk '$2 == 00000000 { print $1 }' /proc/net/route`.strip
  end

  def default_ip_address
    `ip addr show #{default_interface} | awk '$1 == "inet" {print $2}' | cut -f1 -d/`.strip
  end

  def configure
    puts ">>> Setting up velum"
    visit "/setup"
    fill_in "settings_dashboard", with: environment["dashboardHost"] || default_ip_address
    fill_in "settings_apiserver", with: environment["kubernetesHost"]
    click_on "Next"
    puts "<<< Velum set up"
  end
end

RSpec.configure { |config| config.include Helpers, type: :feature }

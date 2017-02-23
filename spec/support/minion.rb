require 'yaml'

# This class is used to access the spawned minions and run commands in them.
# It also provides methods that act as helpers to assertions for tests.
# E.g. When we want to verify a successful orchestration.
class Minion
  extend Helpers # Make the helper methods available

  attr_reader :ip

  # This method returns the ips of all running minions.
  def self.all_ips
    `#{File.join(scripts_path, "minion_ips")}`.split(',').map(&:strip)
  end

  # Returns an Array of Minion instances matching all running minions
  def self.all
    all_ips.map do |ip|
      Minion.new(ip)
    end
  end

  def initialize(ip)
    @ip = ip
  end

  # Returns the roles of this Minion
  def roles
    result = command("salt-call grains.get roles")
    YAML.load(result[:stdout])["local"]
  end

  # Run a command inside the minions. We use ssh to run commands.
  # Returns the output of the command.
  def command(cmd)
    cmd_string = "#{File.join(self.class.scripts_path, "command")} #{ip} '#{cmd}'"
    self.class.system_command(command: cmd_string)
  end

  # Returns true if the given program is running inside of this minion, false
  # otherwise.
  def running?(name)
    !command("pgrep #{name}").strip.match(/^\d+$/).nil?
  end
end

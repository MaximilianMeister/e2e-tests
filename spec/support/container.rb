require_relative "helpers"

# This class is used to access docker containers and run commands in them.
# Our testing environment has some known containers:
# - salt-master
# - salt-api
# - salt-minion-ca
# - mariadb
# - velum
# - velum-event-processor
# - etcd
class Container
  extend Helpers

  attr_reader :name_matching_string

  # name_matching_string is a string which should be included in the container's
  # name. Make sure this is uniq for the container you want.
  def initialize(name_matching_string)
    @name_matching_string = name_matching_string
  end

  # Returns the container id matching the name_matching_string
  def container_id
    command = "docker  ps | grep #{name_matching_string} | head -n 1 | awk '{print $1}'"
    self.class.system_command(command: command)[:stdout]
  end

  def command(command, verbose: false)
    cmd_string = "docker exec #{container_id} #{command}"
    self.class.system_command(command: cmd_string, verbose: verbose)
  end
end

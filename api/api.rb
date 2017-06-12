require "sinatra/base"
require "sinatra/json"

require "json"
require "pathname"

class RspecResultApi < Sinatra::Base
  set :root, File.expand_path("../..", __FILE__)
  set :bind, "0.0.0.0"

  helpers do
    def result_file_path
      Pathname.new(settings.root).join("e2e-result.json")
    end

    def log_path
      Pathname.new(settings.root).join("e2e-tests.log")
    end

    def container_log_path
      Pathname.new(settings.root).join("containers.log")
    end

    def json_result
      JSON.parse(result_file_path.read)
    end

    def run!(env_vars={})
      env_vars.merge!({"VERBOSE" => "true"}).keep_if{ |_,v| ![nil, ""].include?(v) }
      env_var_str = env_vars.map{ |k,v| "#{k}=#{v}" }.join(" ")
      Dir.chdir(settings.root) do
        pid = spawn(
          "#{env_var_str} bundle exec rspec --format json -o e2e-result.json spec/**/*",
          out: "e2e-tests.log",
          err: "e2e-tests.log",
        )
        Process.detach(pid)
      end
    end
  end

  post '/start' do
    env_vars = {}
    env_vars["SALT_BRANCH"] = params["salt-branch"]
    env_vars["VELUM_BRANCH"] = params["velum-branch"]
    env_vars["TERRAFORM_BRANCH"] = params["terraform-branch"]
    env_vars["CONTAINER_MANIFESTS_BRANCH"] = params["container-manifests-branch"]

    run!(env_vars)
  end

  get '/result' do
    json(
      (json_result rescue {}) # when file is empty
    )
  end

  get '/status' do
    json(
      running: (result_file_path.size.zero? rescue false), # when file doesn't exist initially
      success: (json_result["summary"]["failure_count"].zero? rescue false) # when file is empty
    )
  end

  get "/logs" do
    if log_path.exist?
      send_file log_path
    else
      status 404
    end
  end

  get "/containerlogs" do
    if container_log_path.exist?
      send_file container_log_path
    else
      status 404
    end
  end

  run! if app_file == $0
end

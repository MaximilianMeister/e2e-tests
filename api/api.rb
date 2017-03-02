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

    def json_result
      JSON.parse(result_file_path.read)
    end

    def run!
      Thread.new do
        Dir.chdir(settings.root) do
          `VERBOSE=true bundle exec rspec --format json -o e2e-result.json spec/**/* 2>&1 | tee e2e-tests.log`
        end
      end
    end
  end

  post '/start' do
    # if the json file doesn't exist initially
    run! && return unless result_file_path.exist?
    # return temporary unavailable if test is already running
    result_file_path.size.zero? ? (status 503) : run!
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

  run! if app_file == $0
end

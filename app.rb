require 'sinatra/base'
require 'sinatra/reloader'
require_relative './lib/peep'
require_relative './lib/peep_repository'
require_relative './lib/account_repository'

DatabaseConnection.connect

class Application < Sinatra::Base
  # This allows the app code to refresh
  # without having to restart the server.
  configure :development do
    register Sinatra::Reloader
  end

  get "/peeps" do
    peep_repository = PeepRepository.new
    account_repository = AccountRepository.new

    @peeps = peep_repository.all
    @authors = @peeps.map do |peep|
      account_repository.find(peep.account_id)
    end

    return erb(:peeps)
  end

  post "/peeps" do
    if post_inputs_nil?(params)
      status 400
      @error = ArgumentError.new "Cannot have empty fields in the peep form"
      @redirect = { path: "/peeps", message: "Return to Peeps" }
      return erb(:post_error)
    end

    peep = Peep.new
    peep.contents = params[:contents]
    peep.time_posted = params[:time_posted]
    peep.account_id = params[:account_id]

    peep_repository = PeepRepository.new
    peep_repository.create(peep)

    return erb(:post_peep_confirmation)
  end

  get "/peeps/new" do
    @accounts = AccountRepository.new.all
    return erb(:new_peep)
  end

  get "/signup" do

  end

  post "/signup" do
    status 400
    @error = ArgumentError.new "Cannot have empty fields in the signup form"
    @redirect = { path: "/signup", message: "Return to signup page" }
    return erb(:post_error)
  end

  private 

  def post_inputs_nil?(parameters)
    return parameters[:contents].nil? || parameters[:account_id].nil?
  end
end

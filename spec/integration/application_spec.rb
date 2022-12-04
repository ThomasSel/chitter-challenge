require "spec_helper"
require "rack/test"
require "bcrypt"
require_relative '../../lib/account_repository'
require_relative '../../app'

def reset_tables
  sql_seed = File.read('spec/seeds/seeds_peeps.sql')
  connection = DatabaseConnection.connect
  connection.exec(sql_seed)
end

describe Application do
  # This is so we can use rack-test helper methods.
  include Rack::Test::Methods

  # We need to declare the `app` value by instantiating the Application
  # class so our tests work.
  let(:app) { Application.new }

  before(:each) do
    reset_tables
  end

  context "GET /peeps" do
    it "Returns an HTML view with all peeps in reverse chronological order" do
      get_response = get("/peeps")

      expect(get_response.status).to eq 200
      expect(get_response.body).to include(
        '<h1>Chitter</h1>',
        '<a href="/signup"><h2>Signup to Chitter</h2></a>',
        '<a href="/peeps/new"><h2>Post a new peep</h2></a>',
        'TSeleiro',
        'My third peep',
        '2022-11-03 07:13:49'
      )

      # We check that the most recent entry is followed by the second most recent
      expect(get_response.body).to match(
        /2022-11-03 07:13:49<br><br>\s*?<\/div>\s*?<div>\s*?RKirkbride/
      )
    end
  end

  context "POST /peeps" do
    it "Sends error status when wrong / no body parameters are given" do
      post_response = post("/peeps",
        fake_param1: "aksdjh",
        fake_param2: "ldsjfl"
      )
      expect(post_response.status).to eq 400
      expect(post_response.body).to include(
        '<h1>ArgumentError:</h1>',
        '<p>Cannot have empty fields in the peep form</p>',
        '<a href="/peeps"><h3>Return to Peeps</h3></a>'
      )

      post_response = post("/peeps")
      expect(post_response.status).to eq 400
      expect(post_response.body).to include(
        '<h1>ArgumentError:</h1>',
        '<p>Cannot have empty fields in the peep form</p>',
        '<a href="/peeps"><h3>Return to Peeps</h3></a>'
      )
    end

    it "Creates a new peep with a given time_posted" do
      post_response = post("/peeps",
        contents: "Test peep",
        time_posted: "2022-11-04 07:00:00",
        account_id: 2
      )
      expect(post_response.status).to eq 200
      expect(post_response.body).to include(
        '<h3>Your peep has been added</h3>',
        '<a href="/peeps">Return to peeps</a>'
      )

      get_response = get("/peeps")
      expect(get_response.status).to eq 200
      expect(get_response.body).to include(
        'GPaterson',
        'Test peep',
        '2022-11-04 07:00:00'
      )
    end
  end

  context "GET /peeps/new" do
    it "Returns an HTML view with a peep form" do
      get_response = get("/peeps/new")

      expect(get_response.status).to eq 200
      expect(get_response.body).to include(
        '<h1>Post a new peep</h1>',
        '<form action="/peeps" method="POST">',
        '<textarea name="contents" id="contents">',
        '<select name="account_id" id="account_id">',
        '<option value="1">TSeleiro</option>',
        '<input type="submit" name="Submit" />'
      )
    end
  end

  context "GET /signup" do
    it "returns an HTML signup form" do
      get_response = get("/signup")

      expect(get_response.status).to eq 200
      expect(get_response.body).to include(
        '<h1>Sign up to Chitter</h1>',
        '<form action="/signup" method="POST">',
        '<input type="text" name="email" id="email" />',
        '<input type="password" name="password" id="password" />',
        '<input type="text" name="name" id="name" />',
        '<input type="text" name="username" id="username" />',
        '<input type="submit" name="Submit" />',
        '<a href="/peeps">Return to peeps</a>'
      )
    end
  end

  context "POST /signup" do
    it "adds an account to the list of accounts" do
      post_response = post("/signup",
        email: "shah@email.com",
        password: "12344321",
        name: "Shah Hussain",
        username: "SHussain"
      )
      expect(post_response.status).to eq 200
      expect(post_response.body).to include(
        '<h3>Your Chitter account has been created</h3>',
        '<a href="/peeps">Go to the Chitter home page</a>'
      )

      account_repo = AccountRepository.new
      accounts = account_repo.all
      expect(accounts).to include(have_attributes(
        email: "shah@email.com",
        name: "Shah Hussain",
        username: "SHussain"
      ))
      expect(BCrypt::Password.new(accounts.last.password) == "12344321").to eq true
    end
    
    it "fails when adding an account with an email / username that already exists" do
      post_response = post("/signup",
        email: "thomas@email.com",
        password: "password",
        name: "Thomas Seleiro",
        username: "NName"
      )
      expect(post_response.status).to eq 400
      expect(post_response.body).to include(
        '<h1>PG::UniqueViolation:</h1>',
        '<a href="/signup"><h3>Return to signup page</h3></a>'
      )

      post_response = post("/signup",
        email: "new@email.com",
        password: "password",
        name: "Thomas Seleiro",
        username: "TSeleiro"
      )
      expect(post_response.status).to eq 400
      expect(post_response.body).to include(
        '<h1>PG::UniqueViolation:</h1>',
        '<a href="/signup"><h3>Return to signup page</h3></a>'
      )
    end

    it "sends error status when wrong / no body parameters are given" do
      post_response = post("/signup",
        fake_param1: "aksdjh",
        fake_param2: "ldsjfl"
      )
      expect(post_response.status).to eq 400
      expect(post_response.body).to include(
        '<h1>ArgumentError:</h1>',
        '<p>Cannot have empty fields in the signup form</p>',
        '<a href="/signup"><h3>Return to signup page</h3></a>'
      )

      post_response = post("/signup")
      expect(post_response.status).to eq 400
      expect(post_response.body).to include(
        '<h1>ArgumentError:</h1>',
        '<p>Cannot have empty fields in the signup form</p>',
        '<a href="/signup"><h3>Return to signup page</h3></a>'
      )
    end
  end

  context "GET /login" do
    it "returns an HTML view with login form" do
      get_response = get("/login")
      
      expect(get_response.status).to eq 200
      expect(get_response.body).to include(
        '<h1>Sign in to Chitter</h1>',
        '<form action="/login" method="POST">',
        '<input type="text" name="username" id="username" />',
        '<input type="password" name="password" id="password" />',
        '<input type="submit" name="Submit" />'
      )
    end
  end

  context "POST /login" do
    it "sends error status when wrong / no body parameters are given" do
      post_response = post("/login",
        fake_param1: "aksdjh",
        fake_param2: "ldsjfl"
      )
      expect(post_response.status).to eq 400
      expect(post_response.body).to include(
        '<h1>ArgumentError:</h1>',
        '<p>Cannot have empty fields in the login form</p>',
        '<a href="/login"><h3>Return to login page</h3></a>'
      )

      post_response = post("/login")
      expect(post_response.status).to eq 400
      expect(post_response.body).to include(
        '<h1>ArgumentError:</h1>',
        '<p>Cannot have empty fields in the login form</p>',
        '<a href="/login"><h3>Return to login page</h3></a>'
      )
    end

    it "returns failed login view when using a username that doesn't exist" do
      post_response = post("/login",
        username: "TSelerio",
        password: "password"
      )

      expect(post_response.status).to eq 400
      expect(post_response.body).to include(
        '<h1>Chitter login</h1>',
        '<h3>Invalid Username / Password - <a href="/login">Try again</a></h3>'
      )
    end

    it "returns failed login view when using an incorrect password" do
      post_response = post("/login",
        username: "TSeleiro",
        password: "p@$$w0rd"
      )

      expect(post_response.status).to eq 400
      expect(post_response.body).to include(
        '<h1>Chitter login</h1>',
        '<h3>Invalid Username / Password - <a href="/login">Try again</a></h3>'
      )
    end

    it "succeeds when giving the correct authentication" do
      post_response = post("/login",
        username: "TSeleiro",
        password: "password"
      )

      expect(post_response.status).to eq 200
      expect(post_response.body).to include(
        '<h1>Login successful</h1>',
        '<h2>Welcome to Chitter, Thomas Seleiro</h2>',
        '<a href="/peeps">Continue to the main page</a>'
      )
    end
  end
end

# ExJob

ExJob is a zero-dependency, ultra-fast (to be proved), background job processing
library.


All you need is ExJob, no Redis, no internal or external dependencies. Running
ExJob is as simple as adding it to your dependencies and start writing your
first job.

## Usage

ExJob's interface is very similar to other job processing libraries such as
Toniq, Exq. You'll need to defined a job handler:

```elixir
defmodule App.WelcomeEmail do
  use ExJob.Job

  def perform(user) do
    App.Mailer.send_welcome_email(user)
  end
end
```

And then enqueue your job:

```elixir
user = UserRepo.first
#=> %App.User{name: "Jon", email: "jon@example.com"}
ExJob.enqueue(App.WelcomeEmail, [user])
#=> :ok
```

Note that because ExJob is implemented in pure elixir, you can pass any elixir
term to the enqueue function (such as an Ecto struct) as it will not be serialized.

## Installation

Add :ex_job to your **mix.exs** dependencies.

```elixir
def deps do
  [
    {:ex_job, "~> 0.2.0"}
  ]
end
```

ExJob runs as an OTP app, so you will need to add it to your applications as
well:

```elixir
def application do
  [extra_applications: [:ex_job]]
end
```

## Documentation

Documentation is mainly unwritten yet, but it can be found here:
[Documentation](https://hexdocs.pm/ex_job)

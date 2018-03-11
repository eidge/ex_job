defmodule ExJob do
  @moduledoc """
  ExJob is a zero-dependency, ultra-fast ([1](https://github.com/eidge/ex_job_benchmark)),
  background job processing library.


  All you need is ExJob, no Redis, no internal or external dependencies. Running
  ExJob is as simple as adding it to your dependencies and start writing your
  first job.

  ## Usage

  ExJob's interface is very similar to other job processing libraries such as
  Toniq or Exq.

  You'll need to defined a job handler:

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

  ### Grouping Jobs

  By default, ExJob will run each of your jobs concurrently in a different process. But
  sometimes you'll want your jobs to be processed synchronously.

  ExJob allows you to define a `group_by` function inside your job module. Jobs
  for which `group_by` returns the same value will run synchronously in the order
  they were enqueued.

  Let's say you wanted to send multiple text messages to your users, but you want
  to preserve order:

  ```elixir
  defmodule App.Jobs.SendTextMessage do
    use ExJob.Job

    def group_by(%User{id: id}, _message_type), do: id

    def perform(user, message_type) do
      text = App.Messages.for(message_type)
      number = user.phone_number
      Twilio.send(to: number, text: text)
    end
  end
  ```

  You can now enqueue as many messages as you want, and they will be processed in
  the same order as you enqueued them:

  ```elixir
  user = UserRepo.first
  ExJob.enqueue(App.Jobs.SendTextMessage, [user, :welcome])
  ExJob.enqueue(App.Jobs.SendTextMessage, [user, :first_use_voucher])
  ExJob.enqueue(App.Jobs.SendTextMessage, [user, :more_spam])
  ```

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
  """

  alias ExJob.{Central, Pipeline}

  @doc """
  Enqueues a job that will be processed by **job_module** with **args**
  passed to it.
  """
  def enqueue(job_module, args \\ [])
  def enqueue(job_module, args) when is_list(args) do
    job = ExJob.Job.new(job_module, args)
    {:ok, pipeline} = Central.pipeline_for(job_module)
    :ok = Pipeline.enqueue(pipeline, job)
  end
  def enqueue(job_module, args) do
    error = "expected list, got ExJob.enqueue(#{inspect(job_module)}, #{inspect(args)})"
    raise(ArgumentError, error)
  end

  @doc """
  Returns information on jobs, workers and queues.
  """
  def info do
    Central.info()
  end
end

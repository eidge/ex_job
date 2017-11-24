defmodule ExJob.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    ExJob.Application.Supervisor.start_link()
  end
end

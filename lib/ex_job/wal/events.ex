defmodule ExJob.WAL.Events do
  defmodule FileCreated do
    defstruct [:job_module]

    def new(job_module) when is_atom(job_module) do
      %__MODULE__{job_module: job_module}
    end
  end

  defmodule JobEnqueued do
    defstruct [:job_module, :job]

    def new(job = %ExJob.Job{}) do
      %__MODULE__{job_module: job.module, job: job}
    end
  end

  defmodule JobStarted do
    defstruct [:job_module, :job]

    def new(job = %ExJob.Job{}) do
      %__MODULE__{job_module: job.module, job: job}
    end
  end

  defmodule JobDone do
    defstruct [:job_module, :job, :state]

    def new(job = %ExJob.Job{}, state) when is_atom(state) do
      %__MODULE__{job_module: job.module, job: job, state: state}
    end
  end
end

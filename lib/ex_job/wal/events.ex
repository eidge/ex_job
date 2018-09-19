defmodule ExJob.WAL.Events do
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

  defmodule QueueSnapshot do
    defstruct [:job_module, :snapshot]

    def new(job_module, snapshot) when is_atom(job_module) do
      %__MODULE__{job_module: job_module, snapshot: snapshot}
    end
  end
end

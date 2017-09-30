defmodule ExJob.Job do
  @moduledoc false

  alias ExJob.{Dispatcher, GroupDispatcher}

  defstruct [:ref, :module, :arguments, :dispatcher, :queue_name, :arity]

  @doc false
  def new(job_module, args) do
    validate_arity!(job_module.arity(), args)
    group_by = apply(job_module, :group_by, args)
    queue_name = queue_name(job_module, group_by)
    dispatcher = dispatcher(group_by)
    struct!(
      __MODULE__,
      ref: make_ref(),
      module: job_module,
      arguments: args,
      dispatcher: dispatcher,
      queue_name: queue_name,
      arity: job_module.arity()
    )
  end

  defp queue_name(job_module, nil), do: to_string(job_module)
  defp queue_name(job_module, group_by), do: "#{job_module}-#{group_by}"

  defp dispatcher(nil), do: Dispatcher
  defp dispatcher(_group_by), do: GroupDispatcher

  defp validate_arity!(arity, arguments) do
    arg_count = Enum.count(arguments)
    if arity != arg_count do
      raise ArgumentError, "#{inspect(__MODULE__)}.perform/#{arity} takes #{arity} arguments but #{arg_count} arguments were given (arguments: #{inspect(arguments)})"
    end
  end

  @doc false
  defmacro def(call, expr \\ nil) do
    # Keep track of :perform and :group_by function definitions so
    # that we can give the user helpful errors should the spec not be correctly
    # implemented.
    #
    # As we can have any number of arguments, we can't rely on `Behaviour` and
    # the compiler to ensure the user correctly implements a job.
    #
    # These values are used in the __before__compile__ macro to ensure
    # correctness.
    {function_name, _, args} = call
    arg_count = count_arguments(args)

    quote do
      case unquote(function_name) do
        :perform -> @perform_defined unquote(arg_count)
        :group_by -> @group_by_defined unquote(arg_count)
        _ -> nil
      end
      Kernel.def(unquote(call), unquote(expr))
    end
  end

  defp count_arguments(nil), do: 0
  defp count_arguments(args), do: Enum.count(args)

  defmacro __using__(_opts \\ []) do
    quote do
      import Kernel, except: [def: 1, def: 2]
      import unquote(__MODULE__)

      Module.register_attribute __MODULE__, :perform_defined, accumulate: false
      Module.register_attribute __MODULE__, :group_by_defined, accumulate: false

      @perform_defined false
      @group_by_defined false

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    file = env.file
    module = env.module
    arity = Module.get_attribute(module, :perform_defined)
    group_by_arity = Module.get_attribute(module, :group_by_defined)

    quote do
      arity = unquote(arity)
      group_by_arity = unquote(group_by_arity)

      if !arity do
        raise(
          CompileError,
          file: unquote(file),
          description: "#{inspect(unquote(module))} should define a perform/* function"
        )
      end

      if !group_by_arity do
        Kernel.def group_by(unquote_splicing(Macro.generate_arguments(arity, module))), do: nil
      end

      if arity && group_by_arity && arity != group_by_arity do
        raise(
          CompileError,
          file: unquote(file),
          description: "#{inspect(unquote(module))}.perform/#{unquote(arity)} and #{inspect(unquote(module))}.group_by/#{@group_by_defined} should have the same arity"
        )
      end

      Kernel.def arity(), do: unquote(arity)
    end
  end
end

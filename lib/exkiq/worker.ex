defmodule Exkiq.Worker do
  @moduledoc """
  This is used in a jobs module, recommended to be placed in
  lib/jobs.  The jobs module should use Exkiq.Worker and should
  implement a perform function either with or without parameters.
  """
  defmacro __using__(opts \\ []) do
    quote do
      def perform([]) do
        perform()
      end

      def perform_async(params \\ []) do
        Exkiq.enqueue(struct(Exkiq.Job, job(params)))
      end

      def perform_in(minutes, params) do
        Exkiq.enqueue_in(struct(Exkiq.Job, job(params)), minutes)
      end

      def job(params) do
        %{module: __MODULE__,
          retries: retries(),
          queue: queue(),
          params: params
        }
      end

      def queue do
        unquote(opts[:queue] || :default)
      end

      def retries do
        unquote(opts[:retries] || 5)
      end

      defoverridable [perform: 1]
    end
  end
end

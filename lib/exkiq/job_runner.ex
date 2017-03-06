defmodule Exkiq.JobRunner do
  def start_link(job) do
    Task.start_link(fn ->
      GenServer.call(:running, {:monitor, self(), job})
      try do
        apply(job.module, :perform, job.params)
      rescue
        _ -> Process.exit(self(), :error)
      end
    end)
  end
end

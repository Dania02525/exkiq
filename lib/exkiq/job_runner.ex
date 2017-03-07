defmodule Exkiq.JobRunner do
  def start_link(job) do
    Task.start_link(fn ->
      Exkiq.Store.monitor(job, Process.monitor(self()))
      try do
        apply(job.module, :perform, job.params)
      rescue
        _ -> Process.exit(self(), :error)
      end
    end)
  end
end

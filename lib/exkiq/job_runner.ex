defmodule Exkiq.JobRunner do
  def start_link(job) do
    Task.start_link(fn ->
      try do
        apply(job.module, :perform, job.params)
      rescue
        _ ->
          cond do
            job.retries == 0 -> GenStage.cast(:failed, {:enqueue, job})
            true -> GenStage.cast(:retry, {:enqueue, job})
          end
      after
        GenStage.cast(:running, {:dequeue, job})
        Process.exit(self, :normal)
      end
    end)
  end
end

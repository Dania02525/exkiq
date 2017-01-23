defmodule Exkiq.Runner do
  alias Exkiq.Queue

  def start_link do
    pid = Process.spawn(fn-> await() end, [])
    Process.register(pid, :exkiq_runner)
    {:ok, self}
  end

  def process(job) when is_nil(job), do: nil

  def process(job) do
    Process.spawn(fn-> send(:exkiq_runner, do_perform(job)) end, [])
    |> register(job)
    if Exkiq.Threadpool.available? do
      process(Queue.next_job)
    end
  end

  defp await do
    receive do
      {:ok, job} ->
        Exkiq.Store.Succeeded.put(job)
        await
      {:failed, job, error, stacktrace} ->
        if job.retries < 1 do
          Exkiq.Store.Failed.put(job, error, stacktrace)
        else
          Queue.enqueue(struct(job, %{retries: job.retries - 1, queue: :retry}))
        end
        await
      {:DOWN, _ref, :process, pid, _status} ->
        deregister(pid)
        process(Queue.next_job)
      anything ->
        IO.inspect(anything)
        await
    end
  end

  defp register(pid, job) do
    Exkiq.Threadpool.checkout(pid, job)
  end

  defp deregister(pid) do
    Exkiq.Threadpool.checkin(pid)
  end

  defp do_perform(job) do
    try do
      apply(job.module, :perform, job.params)
      {:ok, job}
    rescue
      error ->
        {:failed, job, error, System.stacktrace}
    end
  end
end

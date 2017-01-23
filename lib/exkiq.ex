defmodule Exkiq do
  use Application
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Exkiq.Threadpool, []),
      worker(Exkiq.Queue, []),
      worker(Exkiq.Store, []),
      worker(Exkiq.Runner, [])
    ]
    opts = [strategy: :one_for_one, name: Exkiq.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def running do
    Agent.get(Exkiq.Threadpool, fn threads ->
      threads
    end)
    |> Enum.map(fn(thread)-> thread.job end)
  end

  def queued do
    Exkiq.Queue.all_jobs
  end

  def failed do
    jobs = Agent.get(Exkiq.Store, fn jobs -> jobs end)
    jobs.failed
  end

  def succeeded do
    jobs = Agent.get(Exkiq.Store, fn jobs -> jobs end)
    jobs.succeeded
  end

  def enqueue(job) do
    Exkiq.Queue.enqueue(job)
  end

  def enqueue_in(minutes, job) do
    caller = self()
    Process.spawn(fn-> Process.send_after(caller, {:enqueue, job}, minutes * 1000) end, [])
    await
  end

  def await do
    receive do
      {:enqueue, job} -> enqueue(job)
      _ -> await
    end
  end
end

defmodule Exkiq do
  use Application
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    workers =
      queues()
      |> Enum.map(fn(queue) ->
        worker(Exkiq.Store, [queue], [id: queue])
      end)

    job_managers =
      [supervisor(Exkiq.JobSupervisor, []), worker(Exkiq.JobAggregator, [], [])]

    children = Enum.reverse(job_managers ++ workers)

    opts = [strategy: :one_for_one, name: Exkiq.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def queues do
    static_queues() ++ processable_queues()
  end

  def static_queues do
    [:running, :failed, :succeeded]
  end

  def processable_queues do
    user_defined = Application.get_env(:exkiq, :queues) || []
    [:default, :retry] ++ user_defined
  end

  def stats do
    queues()
    |> Enum.reduce(%{}, fn(queue, acc) ->
      Map.put(acc, queue, Exkiq.Store.dump(queue) |> Enum.count)
    end)
  end

  def dump do
    queues()
    |> Enum.reduce(%{}, fn(queue, acc) ->
      Map.put(acc, queue, Exkiq.Store.dump(queue))
    end)
  end

  def enqueue(job, queue \\ :default) do
    Exkiq.Store.enqueue(job, queue)
  end

  def enqueue_in(job, minutes, queue \\ :default) do
    Exkiq.Store.enqueue_in(job, minutes, queue)
  end

  def master?
    true
  end
end

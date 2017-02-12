defmodule Exkiq do
  use Application
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    workers =
      registered_queues
      |> Enum.map(fn(queue) ->
        worker(Exkiq.Store, [queue], [id: queue])
      end)

    children = Enum.reverse([supervisor(Exkiq.JobSupervisor, []) | workers ])

    opts = [strategy: :one_for_one, name: Exkiq.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def registered_queues do
    user_defined = Application.get_env(:exkiq, :queues) || []
    [:default, :running, :retry, :failed] ++ user_defined
  end

  def proccessable_queues do
    registered_queues
    |> Enum.reject(fn(queue)->
      queue == :running || queue == :failed
    end)
  end

  def stats do
    registered_queues
    |> Enum.reduce(%{}, fn(queue, acc) ->
      Map.put(acc, queue, Exkiq.Store.count(queue))
    end)
  end

  def enqueue(job, queue \\ :default) do
    Exkiq.Store.enqueue(job, queue)
  end

  def enqueue_in(job, minutes, queue \\ :default) do
    Exkiq.Store.enqueue_in(job, minutes, queue)
  end
end

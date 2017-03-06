defmodule Exkiq do
  use Application
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    workers =
      queues()
      |> Enum.map(fn(queue) ->
        worker(Exkiq.Store, [queue], [id: queue])
      end)

    job_manager =
      supervisor(Exkiq.JobManagerSupervisor, [])

    children = Enum.reverse([job_manager | workers])

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

  def master? do
    Node.self() == master()
  end

  def master do
    sorted_nodelist()
    |> List.first
  end

  def sorted_nodelist do
    [ Node.self() | Node.list() ]
    |> Enum.sort
  end

  def nodelist_index do
    Enum.find_index(sorted_nodelist(), fn(e) -> e == Node.self() end)
  end

  def next_node do
    case Enum.at(sorted_nodelist(), nodelist_index() + 1) do
      nil -> master()
      node -> node
    end
  end
end

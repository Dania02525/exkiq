defmodule Exkiq.JobSupervisor do
  use ConsumerSupervisor

  def start_link do
    children = [
      worker(Exkiq.JobRunner, [], restart: :temporary)
    ]

    ConsumerSupervisor.start_link(children, strategy: :one_for_one,
                                            subscribe_to: Exkiq.proccessable_queues,
                                            max_restarts: 0,
                                            max_dynamic: concurrency,
                                            name: __MODULE__)
    {:ok, self}
  end

  def init(_arg) do
    {:consumer, :ok}
  end

  def concurrency do
    Application.get_env(:exkiq, :concurrency) || 10
  end
end

defmodule Exkiq.JobSupervisor do
  use ConsumerSupervisor

  def start_link do
    children = [
      worker(Exkiq.JobRunner, [], restart: :temporary)
    ]

    ConsumerSupervisor.start_link(children, strategy: :one_for_one,
                                            subscribe_to: [{producer(), max_demand: concurrency() + 1}],
                                            max_restarts: 0,
                                            name: __MODULE__)
    {:ok, self()}
  end

  def init(_arg) do
    {:consumer, :ok}
  end

  defp concurrency do
    Application.get_env(:exkiq, :concurrency) || 10
  end

  defp producer do
    :global.whereis_name(Exkiq.JobAggregator)
  end
end

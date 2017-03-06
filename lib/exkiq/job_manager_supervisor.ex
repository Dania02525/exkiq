defmodule Exkiq.JobManagerSupervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    children = [
      worker(Exkiq.JobAggregator, [], [id: :aggregator]),
      supervisor(Exkiq.JobSupervisor, []),
      worker(Exkiq.AggregatorMonitor, [], [])
    ]

    supervise(children, strategy: :one_for_all)
  end
end

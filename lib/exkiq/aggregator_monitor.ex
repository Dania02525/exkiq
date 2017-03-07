defmodule Exkiq.AggregatorMonitor do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  def init([]) do
    run_at_interval()
    {:ok, nil}
  end

  def handle_info(:check_status, state) do
    state = check_status(state)
    run_at_interval()
    {:noreply, state}
  end

  defp run_at_interval do
    Process.send_after(self(), :check_status, 2000)
  end

  defp check_status(pid) do
    case :global.whereis_name(Exkiq.JobAggregator) do
      :undefined -> restart_aggregator
      pid -> pid
    end
  end

  defp restart_aggregator do
    Supervisor.terminate_child(Exkiq.JobManagerSupervisor, :aggregator)
    Supervisor.restart_child(Exkiq.JobManagerSupervisor, :aggregator)
  end

  defp restart_job_manager do
    Supervisor.terminate_child(Exkiq.JobManagerSupervisor, Exkiq.JobSupervisor)
    Supervisor.restart_child(Exkiq.JobManagerSupervisor, Exkiq.JobSupervisor)
  end
end

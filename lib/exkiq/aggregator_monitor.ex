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
    cond do
      :global.whereis_name(Exkiq.JobAggregator) == :undefined ->
        restart_aggregator()
        restart_job_manager()
      :global.whereis_name(Exkiq.JobAggregator) != pid ->
        restart_job_manager()
      true ->
        nil
    end
    :global.whereis_name(Exkiq.JobAggregator)
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

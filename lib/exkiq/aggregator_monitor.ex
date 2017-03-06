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
    {:noreply, state}
  end

  defp run_at_interval do
    Process.send_after(self(), :check_status, 2000)
  end

  defp check_status(pid) do
    cond do
      :global.whereis_name(Exkiq.JobAggregator) == :undefined ->
        Supervisor.terminate_child(Exkiq.JobManagerSupervisor, :aggregator)
        Supervisor.restart_child(Exkiq.JobManagerSupervisor, :aggregator)
        Supervisor.terminate_child(Exkiq.JobManagerSupervisor, Exkiq.JobSupervisor)
        Supervisor.restart_child(Exkiq.JobManagerSupervisor, Exkiq.JobSupervisor)
        :global.whereis_name(Exkiq.JobAggregator)
      :global.whereis_name(Exkiq.JobAggregator) != pid ->
        Supervisor.terminate_child(Exkiq.JobManagerSupervisor, Exkiq.JobSupervisor)
        Supervisor.restart_child(Exkiq.JobManagerSupervisor, Exkiq.JobSupervisor)
        :global.whereis_name(Exkiq.JobAggregator)
      true ->
        pid
    end
    run_at_interval()
  end
end

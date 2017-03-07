defmodule Exkiq.JobAggregator do
  use GenStage

  def start_link do
    case :global.whereis_name(Exkiq.JobAggregator) do
      :undefined ->
        {:ok, pid} = GenStage.start_link(__MODULE__, :ok)
        :global.register_name(__MODULE__, pid, fn(_name, pid1, pid2)->
          cond do
            Exkiq.master? -> pid2
            true -> pid1
          end
        end)
        {:ok, pid}
      pid ->
        {:ok, pid}
    end
  end

  def init(_args) do
    check_interval()
    {:producer, {Exkiq.processable_queues(), 0, %{}}}
  end

  def handle_demand(new_demand, {sources, demand, running}) do
    {sources, demand, to_run} = fetch_jobs(sources, [], demand + new_demand, [])
    {:noreply, to_run, {sources, demand, running}}
  end

  def handle_info(:check_sources, {sources, demand, running}) do
    {sources, demand, to_run} =
      case demand do
        0 ->
          {sources, demand, []}
        _ ->
          fetch_jobs(sources, [], demand, [])
      end
    check_interval()
    {:noreply, to_run, {sources, demand, running}}
  end

  defp check_interval do
    Process.send_after(self(), :check_sources, 5000)
  end

  # base case- no more demand
  defp fetch_jobs(queued, exhausted, 0, to_run) do
    {queued ++ Enum.reverse(exhausted), 0, to_run}
  end

  # base case- exhausted sources
  defp fetch_jobs([], exhausted, demand, to_run) do
    {Enum.reverse(exhausted), demand, to_run}
  end

  defp fetch_jobs([ source | queued ], exhausted, demand, to_run) do
    {to_run, demand, queued, exhausted} =
      case Exkiq.Store.out(source) do
        :empty ->
          # source is exhausted, remove from list and add to exhausted list
          {to_run, demand, queued, [ source | exhausted ]}
        job ->
          # source may still have jobs, put back in queue
          {[ job | to_run ], demand - 1, Enum.reverse([ source | Enum.reverse(queued) ]), exhausted}
      end
    fetch_jobs(queued, exhausted, demand, to_run)
  end
end

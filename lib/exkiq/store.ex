defmodule Exkiq.Store do
  use GenServer

  # API

  def start_link(queue) do
    GenServer.start_link(__MODULE__, :queue.new, name: queue)
  end

  def enqueue(job, queue) do
    GenServer.multi_call(queue, {:enqueue, job})
  end

  # master only
  def out(queue) do
    # get the next job from the master
    case GenServer.call(queue, :out) do
      :empty -> :empty
      job ->
        sync(queue)
        job
    end
  end

  def dump(queue) do
    # just dump the local queue
    GenServer.call(queue, :dump)
  end

  def flush(queue) do
    GenServer.multi_call(queue, :flush)
  end

  # master only
  def sync(queue) do
    cond do
      Exkiq.master?() ->
        GenServer.cast(queue, {:sync, queue, []})
      true ->
        IO.puts "WARNING: sync called on #{inspect Node.self()}, aborting sync"
        :ok
    end
  end

  # Server

  def handle_call(:flush, _from, _jobs) do
    :c.flush()
    {:reply, :ok, :queue.new}
  end

  def handle_call(:dump, _from, jobs) do
    {dump, _reverse} = jobs
    {:reply, dump, jobs}
  end

  def handle_call({:enqueue, job}, _from, jobs) do
    {:reply, :ok, :queue.in(job, jobs)}
  end

  def handle_call(:out, _from, jobs) do
    case :queue.out(jobs) do
      {{_val, job}, remaining_jobs} ->
        {:reply, job, remaining_jobs}
      {:empty, jobs} ->
        {:reply, :empty, jobs}
    end
  end

  def handle_call({:monitor, pid, job}, _from, jobs) do
    job = %{ job | ref: Process.monitor(pid) }
    {:reply, :ok, :queue.in(job, jobs)}
  end

  def handle_cast({:sync, queue, node_jobs}, state) do
    {jobs, _reversed} = state
    case Exkiq.next_node do
      nil ->
        {:noreply, merge_jobs_into_queue(node_jobs, jobs)}
      node ->
         new_jobs = merge_jobs_into_queue(node_jobs, jobs)
        # send the aggregated uniq jobs to the next node
        GenServer.cast({node, queue}, {:sync, queue, new_jobs})
        {:noreply, new_jobs}
    end
  end

  def handle_info({:DOWN, ref, _, _, reason}, jobs) do
    {list, reversed} = jobs
    job = Enum.find(list, fn(j) -> j.ref == ref end)
    cond do
      reason == :normal ->
        Exkiq.Store.enqueue(%{ job | ref: nil }, :succeeded)
      job.retries == 0 ->
        Exkiq.Store.enqueue(%{ job | ref: nil }, :failed)
      true ->
        Exkiq.Store.enqueue(%{ job | ref: nil }, :retry)
    end
    {:noreply, {Enum.reject(list, fn(j) -> j.ref == ref end), Enum.reject(reversed, fn(j) -> j.ref == ref end)}}
  end

  defp merge_jobs_into_queue(node_jobs, jobs) do
    (node_jobs ++ jobs)
    |> Enum.reduce(:queue.new(), fn(job, acc)->
      :queue.in(job, acc)
    end)
  end
end

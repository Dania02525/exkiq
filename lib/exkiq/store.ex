defmodule Exkiq.Store do
  use GenServer

  # API

  def start_link(queue) do
    GenServer.start_link(__MODULE__, :queue.new, name: queue)
  end

  def enqueue(job, queue) do
    GenServer.multi_call(queue, {:enqueue, job})
  end

  def monitor(job, ref) do
    GenServer.abcast(:running, {:monitor, ref, job})
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
    {dump, reverse} = jobs
    {:reply, Enum.uniq(dump ++ reverse), jobs}
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

  def handle_cast({:monitor, ref, job}, jobs) do
    job = %{ job | ref: ref }
    {:noreply, :queue.in(job, jobs)}
  end

  def handle_cast({:sync, queue, node_jobs}, state) do
    {list, rev} = state
    jobs = Enum.uniq(list ++ rev)
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

  def handle_cast({:handle_job_exit, ref, reason}, state) do
    {list, rev} = state
    job = Enum.find(list, fn(j) -> j.ref == ref end) || Enum.find(rev, fn(j) -> j.ref == ref end)
    new_state =
      case {job, reason} do
        {nil, _} ->
          Exkiq.Store.enqueue(%{ job | ref: nil }, :succeeded)
          state
        {job, :normal} ->
          Exkiq.Store.enqueue(%{ job | ref: nil }, :failed)
          {Enum.reject(list, fn(j) -> j.ref == ref end), Enum.reject(rev, fn(j) -> j.ref == ref end)}
        {job, _} ->
          Exkiq.Store.enqueue(%{ job | ref: nil, retries: job.retries - 1 }, :retry)
          {Enum.reject(list, fn(j) -> j.ref == ref end), Enum.reject(rev, fn(j) -> j.ref == ref end)}
      end
    {:noreply, new_state}
  end

  def handle_info({:DOWN, ref, _, _, reason}, state) do
    GenServer.abcast(:running, {:handle_job_exit, ref, reason})
    {:noreply, state}
  end

  defp merge_jobs_into_queue(node_jobs, jobs) do
    (node_jobs ++ jobs)
    |> Enum.reduce(:queue.new(), fn(job, acc)->
      :queue.in(job, acc)
    end)
  end
end

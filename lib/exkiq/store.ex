defmodule Exkiq.Store do
  use GenServer

  # API

  def start_link(queue) do
    GenServer.start_link(__MODULE__, :queue.new, name: queue)
  end

  def enqueue(job, queue) do
    GenServer.call(queue, {:enqueue, job})
  end

  def enqueue_in(job, minutes, queue) do
    Process.send_after(queue, {{:enqueue, job}, queue}, minutes * 1000)
  end

  def out(queue) do
    GenServer.call(queue, :out)
  end

  def dump(queue) do
    GenServer.call(queue, :dump)
  end

  def flush(queue) do
    GenServer.call(queue, :flush)
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

  def handle_call({:monitor, pid, job}, _from, jobs) do
    job = %{ job | ref: Process.monitor(pid) }
    {:reply, :ok, :queue.in(job, jobs)}
  end

  def handle_info({:DOWN, ref, _, _, reason}, jobs) do
    {list, rev} = jobs
    job = Enum.find(list, fn(j) -> j.ref == ref end) || Enum.find(rev, fn(j) -> j.ref == ref end)

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

  def handle_info({{:enqueue, job}, queue}, jobs) do
    GenServer.call(queue, {:enqueue, job})
    {:noreply, jobs}
  end
end

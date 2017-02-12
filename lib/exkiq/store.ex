defmodule Exkiq.Store do
  use GenStage

  # API

  def start_link(queue) do
    GenStage.start_link(__MODULE__, :ok, name: queue)
  end

  def init(_) do
    {:producer, {:queue.new(), 0}}
  end

  def enqueue(job, queue) do
    GenStage.cast(queue, {:enqueue, job})
  end

  def enqueue_in(job, minutes, queue) do
    Process.send_after(queue, {{:enqueue, job}, queue}, minutes * 1000)
  end

  def count(queue) do
    GenStage.call(queue, :count)
  end

  # Server

  def handle_call(:count, _from, {jobs, demand}) do
    {:reply, :queue.len(jobs), [], {jobs, demand}}
  end

  def handle_cast({:enqueue, job}, {jobs, demand}) do
    send_jobs({:queue.in(job, jobs), demand}, [])
  end

  def handle_cast({:dequeue, job}, {jobs, demand}) do
    {l1, l2} = jobs
    new_jobs = {List.delete(l1, job), List.delete(l2, job)}
    {:noreply, [], {new_jobs, demand}}
  end

  def handle_info({{:enqueue, job}, queue}, {jobs, demand}) do
    GenStage.cast(queue, {:enqueue, job})
    {:noreply, [], {jobs, demand}}
  end

  def handle_info(message, {jobs, demand}) do
    IO.puts "Unhandled message received: #{inspect message} in #{queue_name}"
    {:noreply, [], {jobs, demand}}
  end

  def handle_demand(new_demand, {jobs, demand}) do
    send_jobs({jobs, new_demand + demand}, [])
  end

  defp send_jobs({jobs, 0}, jobs_to_run) do
    {:noreply, jobs_to_run, {jobs, 0}}
  end

  defp send_jobs({jobs, demand}, jobs_to_run) do
    case :queue.out(jobs) do
      {{_val, job}, new_jobs} ->
        GenStage.cast(:running, {:enqueue, job})
        send_jobs({new_jobs, demand - 1}, [ job | jobs_to_run ])
      {:empty, jobs} ->
        {:noreply, jobs_to_run, {jobs, demand}}
    end
  end

  defp queue_name do
    case Process.info(self(), :registered_name) do
      {_, []}   -> self()
      {_, name} -> name
    end
  end
end

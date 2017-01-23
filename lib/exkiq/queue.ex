defmodule Exkiq.Queue do
  alias Exkiq.Runner

  def start_link do
    init_job_queues
    Agent.start_link(fn -> registered_queues end, name: __MODULE__)
  end

  def enqueue(job) do
    Agent.update(job.queue, fn jobs ->
      [ %{job | timestamp: timestamp} | jobs ]
    end)
    Runner.process(next_job)
  end

  def next_job do
    queue = next_queue
    job = out(queue)
    cond do
      job == nil -> next_job(queue)
      true -> job
    end
  end

  def next_job(initial_queue) do
    queue = next_queue
    job = out(queue)
    cond do
      queue == initial_queue -> nil
      job == nil -> next_job(initial_queue)
      true -> job
    end
  end

  def all_jobs do
    registered_queues
    |> Enum.reduce([], fn(queue, acc)->
      jobs_in_queue(queue) + acc
    end)
  end

  def jobs_in_queue(queue) do
    Agent.get(queue, fn jobs -> jobs end)
  end

  defp init_job_queues do
    Enum.each(registered_queues, fn(name) ->
      Agent.start_link(fn -> [] end, name: name)
    end)
  end

  defp out(queue) do
    Agent.get_and_update(queue, fn jobs ->
      {List.first(jobs), Enum.drop(jobs, 1)}
    end)
  end

  defp next_queue do
    Agent.get_and_update(__MODULE__, fn queues ->
      {List.first(queues), [List.first(queues) | Enum.reverse(queues)] |> Enum.reverse}
    end)
  end

  defp registered_queues do
    user_defined = Application.get_env(:exkiq, :queues) || []
    [:default, :retry] ++ user_defined
  end

  defp timestamp do
    :calendar.universal_time() |> :calendar.datetime_to_gregorian_seconds()
  end
end

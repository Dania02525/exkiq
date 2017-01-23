defmodule Exkiq.Threadpool do
  alias Exkiq.Thread

  def start_link do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def checkout(pid, job) do
    Agent.update(__MODULE__, fn threads ->
      [ struct(Thread, %{job: job, pid: pid}) | threads ]
    end)
  end

  def checkin(pid) do
    Agent.update(__MODULE__, fn threads ->
      Enum.reject(threads, fn thread -> thread.pid == pid end)
    end)
  end

  def available? do
    (pool_size - occupied) > 0
  end

  def pool_size do
    Application.get_env(:exkiq, :thread_pool_size) || 10
  end

  def occupied do
    Agent.get(__MODULE__, fn threads -> Enum.count(threads) end)
  end
end

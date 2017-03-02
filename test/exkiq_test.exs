defmodule ExkiqTest do
  use ExUnit.Case
  doctest Exkiq

  # always success after 500 ms
  defmodule DefaultWorker do
    use Exkiq.Worker

    def perform do
      send :test, {:running, self()}
      :timer.sleep(1000)
      send :test, {:finished, self()}
    end
  end

  # fail once, then succeed
  defmodule RetryableWorker do
    use Exkiq.Worker, retries: 1

    def perform do
      send :test, {:instruction, self()}
      receive do
        :fail -> raise "something"
        :succeed -> send :test, :finished
      end
    end
  end

  # always fail after 500 ms
  defmodule FailingWorker do
    use Exkiq.Worker, retries: 0

    def perform do
      send :test, {:running, self()}
      :timer.sleep(1000)
      send :test, {:failing, self()}
      raise "something"
    end
  end

  # always success after 5000ms
  defmodule SlowWorker do
    use Exkiq.Worker, retries: 0

    def perform do
      send :test, {:running, self()}
      :timer.sleep(5000)
      send :test, :finished
    end
  end

  def wait_for(message, callback \\ fn from -> from end) do
    receive do
      {^message, from} -> callback.(from)
      _ -> wait_for(message, callback)
    after
      5_000 -> :fail
    end
  end

  setup do
    Process.register(self(), :test)
    :ok
  end

  test "perform with no params and default options" do
    DefaultWorker.perform_async
    wait_for(:running)
    assert Exkiq.stats[:running] == 1
    wait_for(:finished)
    assert Exkiq.stats[:running] == 0
    assert Exkiq.stats[:succeeded] == 1
  end

  test "a failing worker" do
    FailingWorker.perform_async
    wait_for(:running)
    assert Exkiq.stats[:running] == 1
    wait_for(:failing)
    :timer.sleep(200)
    assert Exkiq.stats[:running] == 0
    assert Exkiq.stats[:failed] == 1
    refute_receive :finished
  end

  test "job can fail once and be retried" do
    RetryableWorker.perform_async
    wait_for(:instruction, fn(pid)-> send(pid, :fail) end)
    wait_for(:instruction, fn(pid)-> send(pid, :succeed) end)
    assert Exkiq.stats[:retry] == 0
    assert Exkiq.stats[:succeeded] == 1
    assert_receive :finished
  end

  test "default concurrency maximum of 10 is respected" do
    Enum.each(1..20, fn(_n) -> SlowWorker.perform_async end)
    wait_for(:running)
    assert Exkiq.stats[:running] == 10
  end

  test "failing worker put into retry queue when job runner saturated" do
    RetryableWorker.perform_async
    Enum.each(1..10, fn(_n) -> SlowWorker.perform_async end)
    wait_for(:instruction, fn(pid)-> send(pid, :fail) end)
    :timer.sleep(1000)
    assert Exkiq.stats[:retry] == 1
  end
end

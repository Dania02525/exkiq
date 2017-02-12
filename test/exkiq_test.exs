defmodule ExkiqTest do
  use ExUnit.Case
  doctest Exkiq

  defmodule DefaultWorker do
    use Exkiq.Worker

    def perform do
      :timer.sleep(500)
      send :test, :foo
    end
  end

  defmodule FailingWorker do
    use Exkiq.Worker, retries: 0

    def perform do
      :timer.sleep(500)
      raise "something"
    end
  end

  setup do
    Process.register(self, :test)
    :ok
  end

  test "perform with no params and default options" do
    DefaultWorker.perform_async
    assert Exkiq.stats[:running] == 1
    :timer.sleep(2000)
    assert Exkiq.stats[:running] == 0
    assert_receive :foo
  end

  test "a failing worker" do
    FailingWorker.perform_async
    assert Exkiq.stats[:running] == 1
    :timer.sleep(2000)
    assert Exkiq.stats[:running] == 0
    assert Exkiq.stats[:failed] == 1
    refute_receive :foo
  end
end

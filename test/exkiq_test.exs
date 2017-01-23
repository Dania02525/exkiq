defmodule ExkiqTest do
  use ExUnit.Case
  doctest Exkiq

  defmodule DefaultWorker do
    use Exkiq.Worker

    def perform do
      :timer.sleep(1000)
      send :test, :foo
    end
  end

  setup do
    Process.register(self, :test)
    :ok
  end

  test "perform with no params and default options" do
    DefaultWorker.perform_async
    assert Enum.count(Exkiq.running) == 1
    :timer.sleep(2000)
    assert Enum.count(Exkiq.running) == 0
    # above failing because deregister/1 is never called in runner- not
    # receiving :down tuple?
    assert_receive :foo
  end
end

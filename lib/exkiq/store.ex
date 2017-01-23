defmodule Exkiq.Store do
  def start_link do
    Agent.start_link(fn -> %{failed: [], succeeded: []} end, name: __MODULE__)
  end
end

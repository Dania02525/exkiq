defmodule Exkiq.Store.Succeeded do
  alias Exkiq.Store

  def put(job) do
    Agent.update(Store, fn stores ->
      %{stores | succeeded: [ job | stores.succeeded]}
    end)
  end
end

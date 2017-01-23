defmodule Exkiq.Store.Failed do
  alias Exkiq.Store

  def put(job, _error, _stacktrace) do
    Agent.update(Store, fn stores ->
      %{stores | failed: [ job | stores.failed]}
    end)
  end
end

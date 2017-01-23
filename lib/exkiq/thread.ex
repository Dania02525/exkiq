defmodule Exkiq.Thread do
  defstruct [
    pid: nil,
    job: %Exkiq.Job{}
  ]
end

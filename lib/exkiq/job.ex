defmodule Exkiq.Job do
  defstruct [
    jid: :base64.encode(:crypto.strong_rand_bytes(22)),
    module: nil,
    params: [],
    retries: 5,
    queue: :default,
    status: :queued,
    timestamp: 0
  ]
end

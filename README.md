# Exkiq

**Heavily Sidekiq inspired distributed async job runner for elixir**

When other nodes are connected to an application using Exkiq, the queues are replicated across nodes, and
calls to enqueue jobs are multi-called across nodes to keep in sync.  A master is elected, through which all
consumer supervisors subscribe via the globally registered `Exkiq.JobAggregator` pid.  This means that workload
is distributed across nodes, while consistency and source of truth is maintained through the master.

When a new node joins, the `Exkiq.JobAggregator` registered name is resolved by choosing a master or assigning
to current master node.

When/if the master node goes down, a monitor detects the missing master and elects a new master from the group,
to which the `Exkiq.JobAggregator` process name will point and all consumer supervisors will re subscribe to.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `exkiq` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:exkiq, "~> 0.1.0"}]
    end
    ```

  2. Ensure `exkiq` is started before your application:

    ```elixir
    def application do
      [applications: [:exkiq]]
    end
    ```

    Note: this is clearly in need of more tests, and is using the experimental GenStage and ConsumerSupervisor, which are very likely subject to change.  You probably would not want to use this in production- stick with something like [eqx](https://github.com/akira/exq)

## Use

#### Configuring Exkiq

  Like Sidekiq, Exkiq comes with a :default queue and a :retry queue.  You can also specify the max concurrency here- don't be shy, this is BEAM and unlike ruby, running hundreds or thousands of threads shouldn't be a problem.

  ```elixir
    config :exkiq,
      queues: [:foo_queue, :bar_queue],
      concurrency: 1000
  ```

#### Creating Workers

  In some reasonably named folder (workers?) put your job modules.  They should look something like this with the optional options and using Exkiq.Worker:

  ```elixir
  defmodule MyWorker
    use Exkiq.Worker, retries: 5, queue: :emails

    def perform do
      # do something useful here
    end
  end
  ```

  You can also have parameters for your perform function:

  ```elixir
  def perform(user_id, company_id) do
    # do something even more useful here
  end
  ```

#### Queueing Jobs

  When you want to use these, simply call perform async with your params:

  ```elixir
  MyWorker.perform_async(user.id, user.employer.id)
  ```

  You can also specify a delay, and queue a job after some time - for example 10 minutes:

  ```elixir
  MyWorker.perform_in(10)
  ```

  Jobs that raise an error are sent to the :retry queue if the are configured to be retried.  If a job fails and there are no more retries, it ends up in the :failed queue

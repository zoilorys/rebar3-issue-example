defmodule Frequency do
  @doc """
  Count letter frequency in parallel.

  Returns a map of characters to frequencies.

  The number of worker processes to use can be set with 'workers'.
  """

  @spec frequency([String.t()], pos_integer) :: map
  def frequency(texts, workers) do
    {:ok, sup} = Frequency.Pool.start_link(workers)

    result_maps =
      texts
      |> Enum.map(&Frequency.Pool.run_task/1)
      |> IO.inspect()

    Supervisor.stop(sup, :normal)

    %{}
  end
end

defmodule Frequency.Pool do
  def poolboy_config(workers) do
    [
      name: {:local, :worker},
      worker_module: Frequency.Worker,
      size: workers,
      max_overflow: 2
    ]
  end

  def start_link(workers) do
    children = [
      :poolboy.child_spec(:worker, poolboy_config(workers))
    ]

    opts = [strategy: :one_for_one, name: Frequency.Pool.Supervisor]

    Supervisor.start_link(children, opts)
  end

  def run_task(text) do
    Task.async(fn ->
      :poolboy.transaction(:worker, fn pid ->
        GenServer.call(pid, {:work, text})
      end)
    end)
  end
end

defmodule Frequency.Worker do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [])
  end

  @impl GenServer
  def init(_) do
    {:ok, nil}
  end

  @impl GenServer
  def handle_call({:work, text}, _, state) do
    {:reply, %{text: text}, state}
  end
end

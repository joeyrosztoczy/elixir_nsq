defmodule NSQ.SharedConnectionInfo do
  require Logger

  @doc """
  Given a consumer state object and an nsqd host/port tuple, return the
  connection ID.
  """
  def get_conn_id(parent, {host, port} = _nsqd) do
    "parent:#{inspect parent}:conn:#{host}:#{port}"
  end

  @doc """
  Given a `conn` object return by `Consumer.get_connections`, return the
  connection ID.
  """
  def get_conn_id({conn_id, conn_pid} = _conn) when is_pid(conn_pid) do
    conn_id
  end

  @doc """
  Given a connection state object, return the connection ID.
  """
  def get_conn_id(%{parent: parent, nsqd: {host, port}} = _conn_state) do
    get_conn_id(parent, {host, port})
  end

  @doc """
  Get info for all connections in a map like `%{conn_id: %{... data ...}}`.
  """
  def all_conn_info(agent_pid) when is_pid(agent_pid) do
    Agent.get(agent_pid, fn(data) -> data end)
  end

  @doc """
  `func` is passed `conn_info` for each connection.
  """
  def reduce_conn_info(agent_pid, start_acc, func) do
    Agent.get agent_pid, fn(all_conn_info) ->
      Enum.reduce(all_conn_info, start_acc, func)
    end
  end

  @doc """
  Get info for the connection matching `conn_id`.
  """
  def fetch_conn_info(agent_pid, conn_id) when is_pid(agent_pid) do
    Agent.get(agent_pid, fn(data) -> data[conn_id] || %{} end)
  end

  @doc false
  def fetch_conn_info(%{shared_conn_info_agent: agent_pid}, conn_id) do
    fetch_conn_info(agent_pid, conn_id)
  end

  @doc """
  Get specific data for the connection, e.g.:

      [rdy_count, last_rdy] = fetch_conn_info(pid, "conn_id", [:rdy_count, :last_rdy])
      rdy_count = fetch_conn_info(pid, "conn_id", :rdy_count)
  """
  def fetch_conn_info(agent_pid, conn_id, keys) when is_pid(agent_pid) do
    Agent.get agent_pid, fn(data) ->
      conn_map = data[conn_id] || %{}
      if is_list(keys) do
        Enum.map keys, &Dict.get(conn_map, &1)
      else
        Dict.get(conn_map, keys)
      end
    end
  end

  @doc false
  def fetch_conn_info(%{shared_conn_info_agent: agent_pid} = _state, {conn_id, _conn_pid} = _conn, keys) do
    fetch_conn_info(agent_pid, conn_id, keys)
  end

  @doc false
  def fetch_conn_info(%{shared_conn_info_agent: agent_pid} = _state, conn_id, keys) do
    fetch_conn_info(agent_pid, conn_id, keys)
  end

  @doc """
  Update the info for a specific connection matching `conn_id`. `conn_info` is
  passed to `func`, and the result of `func` is saved as the new `conn_info`.
  """
  def update_conn_info(agent_pid, conn_id, func) when is_pid(agent_pid) and is_function(func) do
    Agent.update agent_pid, fn(data) ->
      Dict.put(data, conn_id, func.(data[conn_id] || %{}))
    end
  end

  @doc """
  Update the info for a specific connection matching `conn_id`. The map is
  merged into the existing conn_info.
  """
  def update_conn_info(agent_pid, conn_id, map) when is_pid(agent_pid) and is_map(map) do
    Agent.update agent_pid, fn(data) ->
      new_conn_data = Dict.merge(data[conn_id] || %{}, map)
      Dict.put(data, conn_id, new_conn_data)
    end
  end

  @doc false
  def update_conn_info(%{shared_conn_info_agent: agent_pid} = state, conn_id, func) do
    update_conn_info(agent_pid, conn_id, func)
  end

  @doc false
  def update_conn_info(%{shared_conn_info_agent: agent_pid, parent: parent, nsqd: nsqd} = state, func) do
    update_conn_info(agent_pid, get_conn_id(parent, nsqd), func)
  end

  @doc """
  Delete connection info matching `conn_id`. This should be called when a
  connection is terminated.
  """
  def delete_conn_info(agent_pid, conn_id) do
    Agent.update(agent_pid, fn(data) -> Dict.delete(data, conn_id) end)
  end

  @doc false
  def delete_conn_info(%{shared_conn_info_agent: agent_pid}, conn_id) do
    delete_conn_info(agent_pid, conn_id)
  end
end
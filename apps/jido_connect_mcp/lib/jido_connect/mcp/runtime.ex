defmodule Jido.Connect.MCP.Runtime do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.MCP.{EndpointResolver, Tool, ToolResult}

  def list_tools(input, opts) do
    with {:ok, endpoint_id} <- EndpointResolver.resolve(input.endpoint_id),
         {:ok, data} <- call_mcp(opts, :list_tools, [endpoint_id], timeout(input)) do
      tools =
        data
        |> Map.get("tools", [])
        |> Enum.map(&Tool.from_mcp/1)
        |> Enum.map(&Tool.to_map/1)

      {:ok, %{endpoint_id: to_string(endpoint_id), tools: tools}}
    end
  end

  def call_tool(input, opts) do
    with {:ok, endpoint_id} <- EndpointResolver.resolve(input.endpoint_id),
         {:ok, data} <-
           call_mcp(
             opts,
             :call_tool,
             [endpoint_id, input.tool_name, input.arguments],
             timeout(input)
           ) do
      result =
        endpoint_id
        |> ToolResult.from_mcp(input.tool_name, data)
        |> ToolResult.to_map()

      {:ok, %{result: result}}
    end
  end

  defp call_mcp(opts, function, args, nil) do
    client = mcp_client(opts)

    with {:ok, response} <- call_client(client, function, args) do
      normalize_response(response)
    end
  end

  defp call_mcp(opts, function, args, timeout) do
    client = mcp_client(opts)

    with {:ok, response} <- call_client(client, function, args ++ [[timeout: timeout]]) do
      normalize_response(response)
    end
  end

  defp call_client(client, function, args) do
    {:ok, apply(client, function, args)}
  rescue
    exception ->
      {:error,
       Error.provider("MCP request failed",
         provider: :mcp,
         reason: :client_exception,
         details: %{
           module: client,
           function: function,
           message: Exception.message(exception)
         }
       )}
  catch
    kind, reason ->
      {:error,
       Error.provider("MCP request failed",
         provider: :mcp,
         reason: :client_exit,
         details: %{
           module: client,
           function: function,
           kind: kind,
           reason: Jido.Connect.Sanitizer.sanitize(reason, :transport)
         }
       )}
  end

  defp normalize_response(response) do
    case response do
      {:ok, %{status: :ok, data: data}} -> {:ok, data}
      {:ok, %{data: data}} -> {:ok, data}
      {:error, error} -> {:error, normalize_error(error)}
      response -> {:error, invalid_response(response)}
    end
  end

  defp mcp_client(%{credentials: credentials}) do
    Map.get(credentials, :mcp_client) || Map.get(credentials, "mcp_client") || Jido.MCP
  end

  defp timeout(input), do: Map.get(input, :timeout)

  defp normalize_error(%{} = error) do
    Error.provider("MCP request failed",
      provider: :mcp,
      reason: Map.get(error, :type) || Map.get(error, "type"),
      details: error
    )
  end

  defp normalize_error(error) do
    Error.provider("MCP request failed",
      provider: :mcp,
      reason: :mcp_error,
      details: %{error: error}
    )
  end

  defp invalid_response(response) do
    Error.provider("MCP request returned an invalid response",
      provider: :mcp,
      reason: :invalid_response,
      details: %{response: Jido.Connect.Sanitizer.sanitize(response, :transport)}
    )
  end
end

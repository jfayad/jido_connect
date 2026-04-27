defmodule Jido.Connect.Http do
  @moduledoc """
  Shared HTTP helpers for provider client modules.

  This is intentionally small. Provider clients still decide endpoint paths,
  request bodies, success payload normalization, and provider-specific API error
  bodies. Core only standardizes request construction and common provider error
  shaping.
  """

  alias Jido.Connect.{Data, Error}

  @user_agent "jido-connect"

  @spec bearer_request(String.t(), String.t(), keyword()) :: Req.Request.t()
  def bearer_request(base_url, access_token, opts \\ [])
      when is_binary(base_url) and is_binary(access_token) do
    Req.new(
      base_url: base_url,
      headers:
        [
          {"authorization", "Bearer #{access_token}"},
          {"user-agent", @user_agent}
        ] ++ Keyword.get(opts, :headers, [])
    )
    |> maybe_merge_req_options(Keyword.get(opts, :req_options, []))
  end

  @spec maybe_merge_req_options(Req.Request.t(), keyword()) :: Req.Request.t()
  def maybe_merge_req_options(request, []), do: request
  def maybe_merge_req_options(request, req_options), do: Req.merge(request, req_options)

  @spec handle_map_response(term(), keyword()) :: {:ok, map()} | {:error, Error.error()}
  def handle_map_response({:ok, %{status: status, body: body}}, _opts)
      when status in 200..299 and is_map(body) do
    {:ok, body}
  end

  def handle_map_response(response, opts), do: provider_error(response, opts)

  @spec provider_error(term(), keyword()) :: {:error, Error.ProviderError.t()}
  def provider_error({:ok, %{status: status, body: body}}, opts) do
    provider = Keyword.fetch!(opts, :provider)
    message = Keyword.get(opts, :message, "#{provider} API request failed")

    {:error,
     Error.provider(message,
       provider: provider,
       reason: Keyword.get(opts, :reason, :http_error),
       status: status,
       details: %{
         message: error_message(body),
         body: body,
         retry_after: retry_after(opts)
       }
     )}
  end

  def provider_error({:error, reason}, opts) do
    provider = Keyword.fetch!(opts, :provider)
    message = Keyword.get(opts, :message, "#{provider} API request failed")

    {:error,
     Error.provider(message,
       provider: provider,
       reason: :request_error,
       details: %{reason: reason}
     )}
  end

  def provider_error(reason, opts) do
    provider = Keyword.fetch!(opts, :provider)
    message = Keyword.get(opts, :message, "#{provider} API request failed")

    {:error,
     Error.provider(message,
       provider: provider,
       reason: :unexpected_response,
       details: %{response: reason}
     )}
  end

  defp error_message(body) when is_map(body), do: Data.get(body, "message", body)
  defp error_message(body), do: body

  defp retry_after(opts), do: Keyword.get(opts, :retry_after)
end

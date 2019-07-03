defmodule K8s.Client.Behaviour do
  @moduledoc "HTTP Request / Response provider behaviour"

  @doc "Generate headers for HTTP Requests"
  @callback headers(atom(), K8s.Conf.RequestOptions.t()) :: list({binary, binary})

  @doc "Perform HTTP Requests"
  @callback request(atom, binary, binary, keyword, keyword) ::
              {:ok, map() | reference()}
              | {:error, atom | HTTPoison.Response.t() | HTTPoison.Error.t()}

  @doc "Handle HTTP Responses"
  @callback handle_response(
              {:ok, HTTPoison.Response.t() | HTTPoison.AsyncResponse.t()}
              | {:error, HTTPoison.Error.t()}
            ) ::
              {:ok, map() | reference()}
              | {:error, atom | HTTPoison.Response.t() | HTTPoison.Error.t()}
end

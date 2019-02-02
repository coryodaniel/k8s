defmodule K8s.Behaviours.HTTPProvider do
  @moduledoc """
  HTTP Request / Response provider behaviour
  """

  @callback headers(K8s.Conf.RequestOptions.t()) :: list({binary, binary})

  @callback request(atom, binary, binary, keyword, keyword) ::
              {:ok, map}
              | {:ok, reference}
              | {:error, atom}
              | {:error, binary}

  @callback handle_response(
              {:ok, HTTPoison.Response.t() | HTTPoison.AsyncResponse.t()}
              | {:error, HTTPoison.Error.t()}
            ) :: {:ok, map()} | {:ok, reference()} | {:error, binary()}
end

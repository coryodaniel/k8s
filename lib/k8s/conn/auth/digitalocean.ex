defmodule K8s.Conn.Auth.DigitalOcean do
  @moduledoc """
  Cluster authentication for kube configs created by doctl, the DigitalOcean CLI
  """

  @behaviour K8s.Conn.Auth

  @impl true
  @spec create(map() | any, String.t() | any) ::
          {:ok, K8s.Conn.Auth.Token.t()} | {:error, any} | :skip
  def create(%{"exec" => %{"command" => "doctl", "args" => args}}, _) do
    with {json, 0} <- System.cmd("doctl", args),
         {:ok, response_map} <- Jason.decode(json),
         token when not is_nil(token) <- get_in(response_map, ["status", "token"]) do
      {:ok, %K8s.Conn.Auth.Token{token: token}}
    end
  end

  def create(_, _), do: :skip
end

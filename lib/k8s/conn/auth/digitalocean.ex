defmodule K8s.Conn.Auth.DigitalOcean do
  @moduledoc """
  Cluster authentication for kube configs created by doctl, the DigitalOcean CLI
  """

  @behaviour K8s.Conn.Auth

  @impl true
  @spec create(map() | any, String.t() | any) :: K8s.Conn.Auth.Token.t() | nil
  def create(%{"exec" => %{"command" => "doctl", "args" => args}}, _) do
    with {json, 0} <- System.cmd("doctl", args),
         {:ok, response_map} <- Jason.decode(json),
         token when not is_nil(token) <- get_in(response_map, ["status", "token"]) do
      %K8s.Conn.Auth.Token{token: token}
    else
      _ -> nil
    end
  end

  def create(_, _), do: nil
end

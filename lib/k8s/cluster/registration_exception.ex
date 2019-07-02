defmodule K8s.Cluster.RegistrationException do
  defexception [:message, :error]

  @impl true
  def exception(error) do
    msg = "Failed to register cluster: #{inspect(error)}"
    %K8s.Cluster.RegistrationException{message: msg, error: error}
  end
end

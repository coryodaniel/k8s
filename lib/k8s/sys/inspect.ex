# credo:disable-for-this-file
defimpl Inspect, for: K8s.Conn.Auth.AuthProvider do
  import Inspect.Algebra

  def inspect(_, _) do
    concat(["K8s.Conn.Auth.AuthProvider<...>"])
  end
end

defimpl Inspect, for: K8s.Conn.Auth.Certificate do
  import Inspect.Algebra

  def inspect(_, _) do
    concat(["K8s.Conn.Auth.Certificate<...>"])
  end
end

defimpl Inspect, for: K8s.Conn.Auth.Token do
  import Inspect.Algebra

  def inspect(_, _) do
    concat(["K8s.Conn.Auth.Token<...>"])
  end
end

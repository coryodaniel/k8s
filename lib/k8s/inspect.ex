# credo:disable-for-this-file
defimpl Inspect, for: K8s.Conf.Auth.AuthProvider do
  import Inspect.Algebra

  def inspect(_, _) do
    concat(["#K8s.Conf.Auth.AuthProvider<...>"])
  end
end

defimpl Inspect, for: K8s.Conf.Auth.Certificate do
  import Inspect.Algebra

  def inspect(_, _) do
    concat(["#K8s.Conf.Auth.Certificate<...>"])
  end
end

defimpl Inspect, for: K8s.Conf.Auth.Token do
  import Inspect.Algebra

  def inspect(_, _) do
    concat(["#K8s.Conf.Auth.Token<...>"])
  end
end

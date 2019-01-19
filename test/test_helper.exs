ExUnit.start()
Application.ensure_all_started(:bypass)
spec = System.get_env("K8S_SPEC") || "priv/swagger/1.13.json"
_router_name = K8s.Router.start(spec)

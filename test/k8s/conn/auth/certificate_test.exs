defmodule K8s.Conn.Auth.CertificateTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias K8s.Conn
  alias K8s.Conn.Auth.Certificate

  describe "create/2" do
    test "creates a Certificate struct from a PEM file" do
      auth = %{
        "client-certificate" => "test/support/tls/certificate.pem",
        "client-key" => "test/support/tls/key.pem"
      }

      assert %Certificate{certificate: cert, key: key} = Certificate.create(auth, ".")
      assert cert
      assert key
    end

    test "creates a Certificate struct from base64 data" do
      auth = %{
        "client-certificate-data" =>
          "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUM5RENDQWR5Z0F3SUJBZ0lJY0FwYS9xZlNVc013RFFZSktvWklodmNOQVFFTEJRQXdGVEVUTUJFR0ExVUUKQXhNS2EzVmlaWEp1WlhSbGN6QWVGdzB4T0RFeE1Ua3dNREk1TlRGYUZ3MHhPVEV5TVRFd01qQTNORGhhTURZeApGekFWQmdOVkJBb1REbk41YzNSbGJUcHRZWE4wWlhKek1Sc3dHUVlEVlFRREV4SmtiMk5yWlhJdFptOXlMV1JsCmMydDBiM0F3Z2dFaU1BMEdDU3FHU0liM0RRRUJBUVVBQTRJQkR3QXdnZ0VLQW9JQkFRRFJqRzdZK2xSN1VlbnMKVUo1aGkvRWlnem53bnpQdWR4NkJLZjkwaG9zVldpeFlZVmlZQ2FYWXhiUk1RMDZQUUhXV2ZVWGEvcEZqWTdQUwpjMllyZ05JZU1oMm5XS2hKbUFGelc5ZFRsV0QrUkNmS3dRVlFYa3ZBVS8rUVczU3pvRUpieHRpczRIc0Vyc2tvCllkeVcxb2hRSm1yc3MxakYzZE93NTQ5cElUSUM3T3VZd0ZQVmx3TWprUmNKUUpMbjJ4UjBIVCt1UmUxTHp0UEoKK2QwdTkvYmpSTERpbnVJYWZhYjZzN3M3Nk52YmJVYXBsSy82RnVxbzhhNUt4Z0lOYXJPNkVHWlZuRU1XMVVxNAorNFVVb1lrdVRWcXJVTlBvSzJ5Yy9wamxySENna3dpTTU3cXNQS00yWVNXRTlXSFZGMGZyZS81bzZtRGRUOU1TCkg5d3ZqNm8vQWdNQkFBR2pKekFsTUE0R0ExVWREd0VCL3dRRUF3SUZvREFUQmdOVkhTVUVEREFLQmdnckJnRUYKQlFjREFqQU5CZ2txaGtpRzl3MEJBUXNGQUFPQ0FRRUFhOHJKUHVsQlMxYWRnb1J5WGo4ak9ZaVpjV3crNUJZTwpuQW5JS2hBWVEvZHBMYXhhcG4zODNHVS9ZeGhKM3E3azExNnZBSmdRTkdPNXBHS3M2b3k3M2FWMGd6ZU00ZklGCnlFN0dNTG1BQVN6QzRJUlIvc0JOWUlKbTlaZERsbmVicEJxTkhIUWt5dlJpdWNMdjFDVDl4dTI0NTBoOW5RSlAKWTJQSmVMSVRhYUhNWVk5eTBPWnQvOGVoNnFyTks2RlY5VWN4bnZYVHQwUW1qL0k2aXdlZ1BVb0t2Vm5aamF0ZQpLOHJMdlQ3SXJLSDRubGRrOUNtclYyZTMwT3IzRVFHeXlOM0xJTGlBa3R2Z3BHNXlLd2s1M2RPSzJtNkl4QTlyCnBzMFRYUmUxMUhlVVhsWm1PcERKVHMwa3VzTGVjVE05ZW5MN1VhK3RSakRtR08xTFo0RDFidz09Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K",
        "client-key-data" =>
          "LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFcEFJQkFBS0NBUUVBMFl4dTJQcFVlMUhwN0ZDZVlZdnhJb001OEo4ejduY2VnU24vZElhTEZWb3NXR0ZZCm1BbWwyTVcwVEVOT2owQjFsbjFGMnY2UlkyT3owbk5tSzREU0hqSWRwMWlvU1pnQmMxdlhVNVZnL2tRbnlzRUYKVUY1THdGUC9rRnQwczZCQ1c4YllyT0I3Qks3SktHSGNsdGFJVUNacTdMTll4ZDNUc09lUGFTRXlBdXpybU1CVAoxWmNESTVFWENVQ1M1OXNVZEIwL3JrWHRTODdUeWZuZEx2ZjI0MFN3NHA3aUduMm0rck83TytqYjIyMUdxWlN2CitoYnFxUEd1U3NZQ0RXcXp1aEJtVlp4REZ0Vkt1UHVGRktHSkxrMWFxMURUNkN0c25QNlk1YXh3b0pNSWpPZTYKckR5ak5tRWxoUFZoMVJkSDYzdithT3BnM1UvVEVoL2NMNCtxUHdJREFRQUJBb0lCQUdwUVY0VGFMTGFNYnFRbwptdEplejY1MDZaWjlEem56VVpTeW5CcWdrRHY3RGZpaEd2TzRJVjZEbjkvNVhnZ3I2Znk1L2hFSGl2ZmtBNzNJCk1wUHJ2YTc0T2pkSE1jcDB4bmVpcHZLUEhUQ2puNVNzcldlREQrZTZOalVsVVdZNDdySGxodFRlNTBzTzZwd0UKV29oa3U2LytiYzA5aU5LS292Wmo1VXl2UE5KaU9oL1l4cmpOdU9KdURWSXNraXExRXRkczdwV21Rb01XcXo5eQowYkxwY1Mwc24zb3I0amxaNy9UcGtsM1cvZEhDWjg5SzB5NTVUNjJnOTY5UFhBTXZCQ2FEMUlEcjRJajhSRGg3CmpBNFFwSXkzKzI0SVBKQWQ0RUw4Qlk3QXIvc0E1SE02R3VLNHo2cURNSXk1UFlYZmIwVzMwNUpGWlJTdEx3cEwKdTJCL1BBRUNnWUVBMjF4eXU3cVZ1QURSNWRZb0NFUXVDMm5SVjBMT3kzNzZRck5XbDlOdzlzcHVWSzBySCtXcQpmeWI4Rnd6Y0FSbkg4K2s2d3FDaUhDVUwrMnYwdGw2Uld1a2txTGJReE9aOVRNYS9PL2lRaVRaUDlZdkM2MUpTCnF2dWlZZ2ZWRVlQWUVyODlNbGxTVGFkRDRLVjJmVnFVa3pHanB5TnBrUzU5b0ZDTFZvMFZDejhDZ1lFQTlJeHEKSDRuYS9BUmZzVkEzR3Q0QzRxblBzQ29qY0tGS0taZ2ZpeGx4a0tOUlMva0FxczU0UTNubXpBNFdRLy9XcmNKQgpmSEFLeFgvM05rdGVjWWRBWmhmY3BIQWVmcmlkUHNDelIvRTg0WUFBS21TdVJZY25OWE9BVmNQd2ExTmJnbFJDCmw0QWN2dk9aTEN5c3I0dWNaYkVtNFBMZURkeUpoUURvZ2dlWW9RRUNnWUVBcDhML09CVk5kV2lqSGp4M1owTUYKVjlNNHQ1eXZYTEFpb3lwV21reXB3d1F6OXV4czQ3c1lkcUFSQVd2alFiQSszSXBOVnhYVWhPUE1VeDlRQ3IwdQpPekc4eUk3d0FQWXBjN000QTV4b3BaZDA5VnhLMlArZm00WlF2Tm95bUcrVnExaTRhNjRtSko4OGFTMEIvb0pzCnlGbVpTRFRzQW8xa3BGdVZCTDluRGE4Q2dZQmVoWU5qUzFKa0JJREVOVUFIVjNhQUM2aWw2N09sRGdKdlQwZ3AKNkp5M2poaVhKOWgxTExiWlJkM0tVMHVSM3Vvb1lTUVVwKzNSNXFNenppL2o2NllkaisyTmRYU2tBRkZ1OXVhVQowUTU2RHBLQjBFWjN3MFNKYVdwYVBCREtPdjdzd2dxM0tpSnlRQStkUG10RXNzNnhrNloyWGdrc0RHanZDcW5UCjBJSFRBUUtCZ1FDUjQ2clpzRDJxUm54S0huYzcyaWRlbjJCK25NQnJoODdmUmE4alBaQU1SajEzTG5RbkxoZHgKV2IwUDdRdFlYWEowTDJkK1FKRFJXZFEzNEZyMmlndkZsUFJkREQzTXJjNVBscEM2Y05HM1BlcndVOFV3VS83UwpuRGhWSWdoRXZRUjFQS29vZFdjMEVrYkxnZ01FdFR2WkdCejVHelVudTY4OXpGV1VzZmtKRHc9PQotLS0tLUVORCBSU0EgUFJJVkFURSBLRVktLS0tLQo="
      }

      assert %Certificate{certificate: cert, key: key} = Certificate.create(auth, ".")
      assert cert
      assert key
    end
  end

  test "creates http request signing options" do
    {:ok, conn} = Conn.from_file("test/support/kube-config.yaml", [])
    assert %Certificate{} = conn.auth

    {:ok, %Conn.RequestOptions{headers: headers, ssl_options: ssl_options}} =
      Conn.RequestOptions.generate(conn.auth)

    assert headers == []
    assert [cert: _, key: _] = ssl_options
  end
end

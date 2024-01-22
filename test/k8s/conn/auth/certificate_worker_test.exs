defmodule K8s.Conn.Auth.CertificateWorkerTest do
  use ExUnit.Case, async: true

  alias K8s.Conn.Auth.CertificateWorker

  describe "start_link/1" do
    test "Runs successfully" do
      # test that certificate and key are read from the file system via genserver
      assert {:ok, pid} =
               CertificateWorker.start_link(
                 cert_path: "test/support/tls/certificate.pem",
                 key_path: "test/support/tls/key.pem",
                 refresh_interval: 100
               )

      # Two requests to get chached values
      assert {:ok, first} = CertificateWorker.get_cert_and_key(pid)
      # Again
      assert {:ok, second} = CertificateWorker.get_cert_and_key(pid)

      # they are indeed the same
      assert first == second
    end

    test "gives errors on read for bad paths" do
      temp_dir = System.tmp_dir!()

      assert {:ok, pid} =
               CertificateWorker.start_link(
                 cert_path: temp_dir <> "/nonexistent.pem",
                 key_path: temp_dir <> "/nonexistent_key.pem",
                 refresh_interval: 100
               )

      assert {:error, _} = CertificateWorker.get_cert_and_key(pid)
    end
  end
end

defmodule K8s.Client.Mint.RequestWindowTest do
  use ExUnit.Case, async: true

  alias K8s.Client.Mint.RequestWindow

  describe "RequestWindow.window_size/2" do
    test ":new defaults work for new requests" do
      # Default frame size is 16_384 and we assume
      # 4096 for overhead so it's the smallest default
      assert 16_384 - 4096 == RequestWindow.window_size(nil, :new)
    end

    test ":new parsed max frame size" do
      assert 420 =
               RequestWindow.window_size(%{server_settings: %{max_frame_size: 420 + 4096}}, :new)
    end

    test ":new wont go below zero" do
      assert 0 = RequestWindow.window_size(%{server_settings: %{max_frame_size: 0}}, :new)
    end

    test "find some deafult from existing requests even in total anarchy" do
      assert 16_384 = RequestWindow.window_size(%{}, %{})
    end
  end
end

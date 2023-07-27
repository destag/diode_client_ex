defmodule DiodeClientTest do
  use ExUnit.Case
  doctest DiodeClient

  test "restore" do
    assert {:ok, sup} = DiodeClient.interface_add("diode_client_test", DiodeClient.Sup)

    DiodeClient.port_listen(5000,
      callback: fn socket ->
        IO.puts("Accepted connection on port 5000")
        IO.inspect(socket)
      end
    )

    assert %{5000 => _sock} = DiodeClient.Acceptor.all_ports()
    :ok = Supervisor.terminate_child(sup, DiodeClient.Acceptor)
    {:ok, _pid} = Supervisor.restart_child(sup, DiodeClient.Acceptor)
    assert %{5000 => _sock} = DiodeClient.Acceptor.all_ports()
  end
end

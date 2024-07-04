defmodule DiodeClient.TicketV2 do
  @moduledoc false
  alias DiodeClient.{Wallet, Secp256k1, Hash, ABI}
  require Record

  Record.defrecord(:ticketv2,
    server_id: nil,
    chain_id: nil,
    epoch: nil,
    fleet_contract: nil,
    total_connections: nil,
    total_bytes: nil,
    local_address: nil,
    device_signature: nil,
    server_signature: nil
  )

  @type t ::
          record(:ticketv2,
            server_id: binary(),
            chain_id: binary(),
            epoch: integer(),
            fleet_contract: binary(),
            total_connections: integer(),
            total_bytes: integer(),
            local_address: binary(),
            device_signature: Secp256k1.signature(),
            server_signature: Secp256k1.signature() | nil
          )

  def key(tck = ticketv2()) do
    device_address(tck)
  end

  def device_wallet(tck = ticketv2()) do
    Secp256k1.recover!(
      device_signature(tck),
      device_blob(tck),
      :kec
    )
    |> Wallet.from_pubkey()
  end

  def device_address(tck = ticketv2()) do
    device_wallet(tck)
    |> Wallet.address!()
  end

  def device_address?(tck = ticketv2(), wallet) do
    Secp256k1.verify(
      Wallet.pubkey!(wallet),
      device_blob(tck),
      device_signature(tck),
      :kec
    )
  end

  def device_sign(tck = ticketv2(), private) do
    ticketv2(tck, device_signature: Secp256k1.sign(private, device_blob(tck), :kec))
  end

  def server_sign(tck = ticketv2(), private) do
    ticketv2(tck, server_signature: Secp256k1.sign(private, server_blob(tck), :kec))
  end

  @doc """
    Format for putting into a transaction with "SubmitTicketRaw"
  """
  def raw(tck = ticketv2()) do
    [rec, r, s] = Secp256k1.bitcoin_to_rlp(device_signature(tck))

    [
      block_number(tck),
      fleet_contract(tck),
      server_id(tck),
      total_connections(tck),
      total_bytes(tck),
      Hash.sha3_256(local_address(tck)),
      r,
      s,
      rec
    ]
  end

  def summary(tck) do
    [
      chain_id(tck),
      epoch(tck),
      total_connections(tck),
      total_bytes(tck),
      local_address(tck),
      device_signature(tck)
    ]
  end

  def device_blob(tck = ticketv2()) do
    [
      chain_id(tck),
      epoch(tck),
      fleet_contract(tck),
      server_id(tck),
      total_connections(tck),
      total_bytes(tck),
      Hash.sha3_256(local_address(tck))
    ]
    |> Enum.map(&ABI.encode("bytes32", &1))
    |> :erlang.iolist_to_binary()
  end

  def server_blob(tck = ticketv2()) do
    [device_blob(tck), device_signature(tck)]
    |> :erlang.iolist_to_binary()
  end

  # def epoch(ticketv2), do: block(ticketv2) |> Block.epoch()

  def server_id(ticketv2(server_id: id)), do: id
  def chain_id(ticketv2(chain_id: chain_id)), do: chain_id
  def epoch(ticketv2(epoch: epoch)), do: epoch

  # Block number is used as a hint for age of the object to
  # be able to discard older objects. Using epoch is enough
  def block_number(t = ticketv2(epoch: epoch)), do: epoch * 0xFFFFFFFFFFFFFFFF + total_bytes(t)
  def device_signature(ticketv2(device_signature: signature)), do: signature
  def server_signature(ticketv2(server_signature: signature)), do: signature
  def fleet_contract(ticketv2(fleet_contract: fc)), do: fc
  def total_connections(ticketv2(total_connections: tc)), do: tc
  def total_bytes(ticketv2(total_bytes: tb)), do: tb
  def local_address(ticketv2(local_address: la)), do: la

  def preferred_server_ids(ticketv2(server_id: id, local_address: la)) do
    case la do
      <<0, addr::binary-size(20)>> -> [addr, id]
      <<1, addr::binary-size(20)>> -> [id, addr]
      _ -> [id]
    end
  end

  def message(tck = ticketv2()) do
    [
      "ticketv2",
      chain_id(tck),
      epoch(tck),
      fleet_contract(tck),
      total_connections(tck),
      total_bytes(tck),
      local_address(tck),
      device_signature(tck)
    ]
  end
end

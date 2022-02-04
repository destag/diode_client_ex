defmodule DiodeClient.Wallet do
  alias DiodeClient.{Base16, Hash, Secp256k1, Wallet}

  @moduledoc """
  Might be merged with Id.ex, for now just starting with clear Ethereum triple needed for wallets:
  1) Private Key
  2) Public Key
  3) Address
  A wallet can be instantiated from any of those, but accessors for higher level ids fail
  """
  @type private_key :: <<_::256>>
  @type compressed_public_key :: <<_::264>>
  @type address :: <<_::160>>

  require Record
  Record.defrecord(:wallet, privkey: nil, pubkey: nil, address: nil)

  @type t ::
          record(:wallet, privkey: nil | <<_::256>>, pubkey: nil | <<_::264>>, address: <<_::160>>)

  @spec new :: Wallet.t()
  def new() do
    {_public, private} = Secp256k1.generate()
    from_privkey(private)
  end

  @spec from_privkey(<<_::256>> | integer()) :: Wallet.t()
  def from_privkey(privkey) when is_integer(privkey) do
    from_privkey(<<privkey::unsigned-size(256)>>)
  end

  def from_privkey(privkey = <<_::256>>) do
    {:ok, pubkey} = Secp256k1.generate_public_key(privkey)
    pubkey = Secp256k1.compress_public(pubkey)
    wallet(from_pubkey(pubkey), privkey: privkey)
  end

  @spec from_pubkey(<<_::264>>) :: Wallet.t()
  def from_pubkey(pubkey = <<_::264>>) do
    address =
      Secp256k1.decompress_public(pubkey)
      |> binary_part(1, 64)
      |> Hash.keccak_256()
      |> binary_part(12, 20)

    wallet(from_address(address), pubkey: pubkey)
  end

  def from_pubkey(pubkey) when is_binary(pubkey) do
    from_pubkey(Secp256k1.compress_public(pubkey))
  end

  @spec from_address(<<_::160>> | integer) :: Wallet.t()
  def from_address(address) when is_integer(address) do
    wallet(address: <<address::unsigned-size(160)>>)
  end

  def from_address(address = <<_::160>>) do
    wallet(address: address)
  end

  @spec address!(Wallet.t()) :: <<_::160>>
  def address!(wallet) do
    {:ok, address} = address(wallet)
    address
  end

  @spec address(Wallet.t()) :: {:error, nil} | {:ok, <<_::160>>}
  def address(wallet(address: nil)), do: {:error, nil}
  def address(wallet(address: address)), do: {:ok, address}

  def printable(nil), do: "nil"

  def printable(wallet),
    do: "#{base16(wallet)}"

  def nick(nil), do: "nil"

  def nick(wallet),
    do: "#{String.slice(base16(wallet), 0..5)}"

  def base16(wallet) do
    Base16.encode(address!(wallet))
  end

  def pubkey!(wallet) do
    {:ok, pubkey} = pubkey(wallet)
    pubkey
  end

  def pubkey(wallet(pubkey: nil)), do: {:error, nil}
  def pubkey(wallet(pubkey: pubkey)), do: {:ok, pubkey}

  def pubkey_long(wallet(pubkey: pubkey)), do: {:ok, Secp256k1.decompress_public(pubkey)}

  def pubkey_long!(wallet) do
    {:ok, pubkey_long} = pubkey_long(wallet)
    pubkey_long
  end

  def privkey!(wallet) do
    {:ok, privkey} = privkey(wallet)
    privkey
  end

  def privkey(wallet(privkey: nil)), do: {:error, nil}
  def privkey(wallet(privkey: privkey)), do: {:ok, privkey}

  def privkey?(wallet(privkey: nil)), do: false
  def privkey?(wallet(privkey: _privkey)), do: true

  def equal?(wallet() = a, wallet() = b) do
    address!(a) == address!(b)
  end

  def equal?(a = <<_::160>>, b) do
    equal?(from_address(a), b)
  end

  def equal?(a, b = <<_::160>>) do
    equal?(a, from_address(b))
  end

  def equal?(_, _) do
    false
  end
end

defimpl Inspect, for: DiodeClient.Wallet do
  import Inspect.Algebra

  def inspect(wallet, _opts) do
    concat(["#Wallet<", DiodeClient.Wallet.printable(wallet), ">"])
  end
end

defmodule Revix.Ecto.Visibility do
  @moduledoc """
  Post visibility: who can see an entry.

  - `:public` — everyone, including anonymous visitors and remote instances
  - `:instance` — any signed-in local user; not federated off-instance
  - `:followers` — the author and their accepted followers (federated to the
    followers collection, Mastodon-style)
  - `:private` — the author only; never federated
  """
  use Ecto.Type

  def type, do: :string

  def cast(:private), do: {:ok, :private}
  def cast(:followers), do: {:ok, :followers}
  def cast(:instance), do: {:ok, :instance}
  def cast(:public), do: {:ok, :public}
  def cast("private"), do: {:ok, :private}
  def cast("followers"), do: {:ok, :followers}
  def cast("instance"), do: {:ok, :instance}
  def cast("public"), do: {:ok, :public}
  def cast(_), do: :error

  def load("private"), do: {:ok, :private}
  def load("followers"), do: {:ok, :followers}
  def load("instance"), do: {:ok, :instance}
  def load("public"), do: {:ok, :public}
  def load(_), do: :error

  def dump(:private), do: {:ok, "private"}
  def dump(:followers), do: {:ok, "followers"}
  def dump(:instance), do: {:ok, "instance"}
  def dump(:public), do: {:ok, "public"}
  def dump(_), do: :error

  def values, do: [:private, :followers, :instance, :public]
end

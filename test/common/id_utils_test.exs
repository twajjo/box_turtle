defmodule BoxTurtle.Common.IdUtilsTest do
  use ExUnit.Case, async: true

  alias BoxTurtle.Common.IdUtils
  alias BoxTurtle.Schema.Ecto.Ksuid

  test "generate_id/0 returns an integer in range" do
    id = IdUtils.generate_id()
    assert is_integer(id) and id in 1..1_000_000_000
  end

  test "generate_ksuid/0 and generate_uid/0 return valid KSUIDs" do
    assert Ksuid.valid?(IdUtils.generate_ksuid())
    assert Ksuid.valid?(IdUtils.generate_uid())
    assert IdUtils.generate_ksuid() != IdUtils.generate_ksuid()
  end

  test "generate_uuid/0 returns a UUID" do
    assert {:ok, _} = Ecto.UUID.cast(IdUtils.generate_uuid())
  end
end

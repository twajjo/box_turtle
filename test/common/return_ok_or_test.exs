defmodule BoxTurtle.Common.ReturnOkOrTest do
  use ExUnit.Case, async: true

  import BoxTurtle.Common.ReturnOkOr
  import ExUnit.CaptureLog

  describe "return_ok_or/2" do
    test "wraps a bare value in an ok tuple" do
      assert return_ok_or(%{id: 1}, :not_found) == {:ok, %{id: 1}}
      assert return_ok_or(false, :not_found) == {:ok, false}
    end

    test "passes an ok tuple through" do
      assert return_ok_or({:ok, 1}, :not_found) == {:ok, 1}
    end

    test "turns nil, :error and error tuples into {:error, reason}" do
      assert return_ok_or(nil, :not_found) == {:error, :not_found}
      assert return_ok_or(:error, :not_found) == {:error, :not_found}
      assert return_ok_or({:error, :timeout}, :not_found) == {:error, :not_found}
    end
  end

  describe "return_ok_or/1" do
    test "passes result shapes through unchanged" do
      assert return_ok_or({:ok, 1}) == {:ok, 1}
      assert return_ok_or({:error, :boom}) == {:error, :boom}
      assert return_ok_or(:error) == :error
    end

    test "raises for anything else" do
      assert_raise FunctionClauseError, fn -> return_ok_or(Enum.random([nil, 42])) end
    end
  end

  test "return_error/1 wraps the reason" do
    assert return_error(:nope) == {:error, :nope}
  end

  describe "logging macros" do
    @describetag :capture_log

    test "error_with_stack/1 logs the message and the caller's stack trace" do
      log = capture_log(fn -> error_with_stack("it broke") end)
      assert log =~ "[error]"
      assert log =~ ~s("it broke")
      assert log =~ "ReturnOkOrTest"
    end

    test "warn_with_stack/1 logs at warning level" do
      log = capture_log(fn -> warn_with_stack(:careful) end)
      assert log =~ "[warning]"
      assert log =~ ":careful"
    end
  end
end

defmodule HelloOryTest do
  use ExUnit.Case
  doctest HelloOry

  test "greets the world" do
    assert HelloOry.hello() == :world
  end
end

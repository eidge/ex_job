defmodule RexTest do
  use ExUnit.Case
  doctest Rex

  test "greets the world" do
    assert Rex.hello() == :world
  end
end

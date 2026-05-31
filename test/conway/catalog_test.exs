defmodule Conway.CatalogTest do
  use ExUnit.Case, async: true
  alias Conway.{Catalog, Pattern}

  defp cat do
    Catalog.new([
      %Pattern{name: "glider"},
      %Pattern{name: "block"},
      %Pattern{name: "Gosper glider gun"}
    ])
  end

  test "current starts at the first pattern" do
    assert Catalog.current(cat()).name == "glider"
  end

  test "next and prev wrap around" do
    c = cat()
    assert c |> Catalog.next() |> Catalog.current() |> Map.get(:name) == "block"
    assert c |> Catalog.next() |> Catalog.next() |> Catalog.next() |> Catalog.current() |> Map.get(:name) == "glider"
    assert c |> Catalog.prev() |> Catalog.current() |> Map.get(:name) == "Gosper glider gun"
  end

  test "select jumps to an index" do
    assert cat() |> Catalog.select(1) |> Catalog.current() |> Map.get(:name) == "block"
  end

  test "search is case-insensitive substring match returning {index, pattern}" do
    results = Catalog.search(cat(), "gli")
    assert Enum.map(results, fn {i, p} -> {i, p.name} end) == [{0, "glider"}, {2, "Gosper glider gun"}]
  end

  test "an empty catalog is safe" do
    c = Catalog.new([])
    assert Catalog.current(c) == nil
    assert Catalog.next(c) == c
    assert Catalog.search(c, "x") == []
  end
end

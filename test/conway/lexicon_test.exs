defmodule Conway.LexiconTest do
  use ExUnit.Case, async: true
  alias Conway.Lexicon

  @sample """
  This is preamble text before any entry. It must be ignored.

  :glider: (c/4 diagonal) The smallest spaceship.
          .*.
          ..*
          ***

  :p2 concept: A definition with no diagram, so it is skipped.

  :block: A still life.
          **
          **
  """

  test "parses entries that have a diagram and skips the rest" do
    patterns = Lexicon.parse(@sample)
    names = Enum.map(patterns, & &1.name)
    assert names == ["glider", "block"]
  end

  test "captures the description text from the header line" do
    [glider | _] = Lexicon.parse(@sample)
    assert glider.name == "glider"
    assert glider.description =~ "smallest spaceship"
    assert glider.cells == MapSet.new([{1, 0}, {2, 1}, {0, 2}, {1, 2}, {2, 2}])
  end

  test "preserves horizontal alignment by stripping only the common indent" do
    text = ":offset: desc\n          .*\n          *.\n"
    [p] = Lexicon.parse(text)
    assert p.cells == MapSet.new([{1, 0}, {0, 1}])
  end

  describe "load/0 against the vendored file" do
    test "parses a large catalog including well-known patterns" do
      patterns = Lexicon.load()
      assert length(patterns) > 500

      names = MapSet.new(patterns, &String.downcase(&1.name))
      assert MapSet.member?(names, "glider")
      assert Enum.any?(names, &String.contains?(&1, "gosper glider gun"))

      glider = Enum.find(patterns, &(String.downcase(&1.name) == "glider"))
      assert MapSet.size(glider.cells) == 5
    end
  end
end

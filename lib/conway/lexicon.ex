defmodule Conway.Lexicon do
  @moduledoc """
  Parser and loader for the Life Lexicon plaintext format (dvgrn/life-lexicon,
  CC BY-SA 3.0). Entries start at column 0 with `:Name:`; pattern diagrams are
  indented blocks of `.`/`*` lines terminated by a blank or unindented line.
  Entries with no diagram are skipped.
  """

  alias Conway.Pattern

  @header ~r/^:([^:]+):\s?(.*)$/
  @diagram_row ~r/^\s+[.*O]+$/

  @doc "Parse lexicon text into a list of `Conway.Pattern`."
  @spec parse(String.t()) :: [Pattern.t()]
  def parse(text) do
    text
    |> String.split(~r/\r\n|\r|\n/)
    |> chunk_entries()
    |> Enum.map(&entry_to_pattern/1)
    |> Enum.reject(&(is_nil(&1) or MapSet.size(&1.cells) == 0))
  end

  @doc "Read and parse the vendored lexicon file from `priv/`."
  @spec load() :: [Pattern.t()]
  def load do
    path = Path.join(to_string(:code.priv_dir(:conway)), "life-lexicon.txt")

    path
    |> File.read!()
    |> parse()
  end

  # Group lines into {name, body_lines}, one per `:Name:` header. Lines before
  # the first header (the license preamble) are dropped.
  defp chunk_entries(lines) do
    {entries, current} = Enum.reduce(lines, {[], nil}, &accumulate_line/2)

    push(entries, current)
    |> Enum.reverse()
    |> Enum.map(fn {name, body} -> {name, Enum.reverse(body)} end)
  end

  defp accumulate_line(line, {entries, current}) do
    case Regex.run(@header, line) do
      [_, name, rest] ->
        {push(entries, current), {name, [rest]}}

      nil ->
        case current do
          nil -> {entries, nil}
          {name, body} -> {entries, {name, [line | body]}}
        end
    end
  end

  defp push(entries, nil), do: entries
  defp push(entries, entry), do: [entry | entries]

  defp entry_to_pattern({name, body}) do
    {desc_lines, rest} = Enum.split_while(body, &(not diagram_row?(&1)))
    diagram = Enum.take_while(rest, &diagram_row?/1)

    case diagram do
      [] ->
        nil

      _ ->
        description =
          desc_lines
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
          |> Enum.join(" ")

        Pattern.from_ascii(name, description, strip_common_indent(diagram))
    end
  end

  defp diagram_row?(line), do: Regex.match?(@diagram_row, String.trim_trailing(line))

  defp strip_common_indent(lines) do
    min_indent =
      lines
      |> Enum.map(fn l -> String.length(l) - String.length(String.trim_leading(l)) end)
      |> Enum.min()

    Enum.map(lines, &String.slice(&1, min_indent..-1//1))
  end
end

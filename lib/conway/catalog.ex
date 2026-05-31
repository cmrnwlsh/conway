defmodule Conway.Catalog do
  @moduledoc """
  A navigable index over a list of `Conway.Pattern`: a current selection with
  next/prev wraparound and case-insensitive name search.
  """

  alias Conway.Pattern
  alias __MODULE__

  @type t :: %Catalog{patterns: tuple(), count: non_neg_integer(), index: non_neg_integer()}

  defstruct patterns: {}, count: 0, index: 0

  @spec new([Pattern.t()]) :: t()
  def new(patterns) when is_list(patterns) do
    %Catalog{patterns: List.to_tuple(patterns), count: length(patterns), index: 0}
  end

  @spec current(t()) :: Pattern.t() | nil
  def current(%Catalog{count: 0}), do: nil
  def current(%Catalog{patterns: p, index: i}), do: elem(p, i)

  @spec at(t(), non_neg_integer()) :: Pattern.t()
  def at(%Catalog{patterns: p}, i), do: elem(p, i)

  @spec next(t()) :: t()
  def next(%Catalog{count: 0} = c), do: c
  def next(%Catalog{index: i, count: n} = c), do: %{c | index: rem(i + 1, n)}

  @spec prev(t()) :: t()
  def prev(%Catalog{count: 0} = c), do: c
  def prev(%Catalog{index: i, count: n} = c), do: %{c | index: rem(i - 1 + n, n)}

  @spec select(t(), non_neg_integer()) :: t()
  def select(%Catalog{count: n} = c, i) when is_integer(i) and i >= 0 and i < n,
    do: %{c | index: i}

  @doc "All `{index, pattern}` whose name contains `query` (case-insensitive)."
  @spec search(t(), String.t()) :: [{non_neg_integer(), Pattern.t()}]
  def search(%Catalog{count: 0}, _query), do: []

  def search(%Catalog{patterns: p, count: n}, query) do
    q = String.downcase(query)

    for i <- 0..(n - 1)//1,
        pat = elem(p, i),
        String.contains?(String.downcase(pat.name), q),
        do: {i, pat}
  end
end

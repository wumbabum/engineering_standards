Code.require_file("lib/standards.ex", __DIR__)

defmodule Lint do
  @moduledoc """
  Validate the standards docs against the strict format and the 1:1 rule<->references
  contract. Prints actionable errors and exits non-zero on any violation.
  """

  def run do
    docs = Standards.docs()
    errors = Enum.flat_map(docs, &check/1)

    if errors == [] do
      rules = Enum.sum(Enum.map(docs, fn doc -> length(Standards.parse_doc(doc).rules) end))
      IO.puts("lint: OK (#{length(docs)} docs, #{rules} rules, 1:1 with references)")
    else
      IO.puts(:stderr, "lint: #{length(errors)} problem(s):")
      Enum.each(errors, &IO.puts(:stderr, "  - #{&1}"))
      System.halt(1)
    end
  end

  defp check(path) do
    lines = path |> File.read!() |> String.split("\n")
    format_errors(path, lines) ++ contract_errors(path)
  end

  # -- raw-format checks (independent of the parser) --
  defp format_errors(path, lines) do
    {h1, h3, ref_urls, _fence} =
      Enum.reduce(lines, {0, 0, 0, false}, fn line, {h1, h3, ref_urls, fence} ->
        cond do
          String.starts_with?(line, "```") -> {h1, h3, ref_urls, not fence}
          fence -> {h1, h3, ref_urls + count_ref_urls(line), fence}
          String.starts_with?(line, "# ") -> {h1 + 1, h3, ref_urls + count_ref_urls(line), fence}
          String.starts_with?(line, "### ") -> {h1, h3 + 1, ref_urls + count_ref_urls(line), fence}
          true -> {h1, h3, ref_urls + count_ref_urls(line), fence}
        end
      end)

    []
    |> add(h1 == 1, "#{path}: expected exactly one H1 title, found #{h1}")
    |> add(h3 == 0, "#{path}: uses `### ` headings, which are reserved; rules must be `#### ` under a `## ` section")
    |> add(ref_urls == 0, "#{path}: contains PR/discussion reference URLs; references belong in the store, not the doc")
  end

  defp count_ref_urls(line), do: length(Regex.scan(~r/discussion_r\d+/, line))

  defp add(errors, true, _msg), do: errors
  defp add(errors, false, msg), do: errors ++ [msg]

  # -- parser + 1:1 contract checks --
  defp contract_errors(path) do
    {parsed, errors} = Standards.validate_doc(path)
    empty = if parsed.rules == [], do: ["#{path}: no `#### ` rules found"], else: []
    errors ++ empty
  end
end

Lint.run()

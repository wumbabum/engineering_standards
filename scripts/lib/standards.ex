defmodule Standards do
  @moduledoc """
  Shared helpers for the standards toolchain: parse a theme doc into rules, slugify
  rule names, render the supported Markdown subset to HTML, and load a references store.
  Hand-rolled (no Markdown dependency). JSON via OTP `:json`.
  """

  @collection_dir "standards/elixir"
  @store_dir "references/elixir"

  # ---------------------------------------------------------------- discovery
  def docs do
    Path.wildcard("#{@collection_dir}/*.md")
    |> Enum.reject(&(Path.basename(&1) == "README.md"))
    |> Enum.sort()
  end

  def store_path(doc_path),
    do: "#{@store_dir}/#{Path.basename(doc_path, ".md")}.json"

  # ---------------------------------------------------------------- parsing
  # Returns %{title, scope, rules: [%{name, slug, section, body: [line]}]}
  def parse_doc(path) do
    path
    |> File.read!()
    |> String.split("\n")
    |> Enum.reduce(%{title: nil, scope: nil, section: nil, cur: nil, rules: [], fence: false}, &parse_line/2)
    |> flush()
    |> finalize()
  end

  defp finalize(acc), do: %{title: acc.title, scope: acc.scope, rules: Enum.reverse(acc.rules)}

  defp parse_line("```" <> _ = line, acc), do: add(%{acc | fence: not acc.fence}, line)
  defp parse_line(line, %{fence: true} = acc), do: add(acc, line)

  defp parse_line("# " <> rest, acc), do: %{acc | title: String.trim(rest)}

  defp parse_line("#### " <> rest, acc) do
    acc = flush(acc)
    name = String.trim(rest)
    %{acc | cur: %{name: name, slug: slugify(name), section: acc.section, body: []}}
  end

  defp parse_line("## " <> rest, acc), do: %{flush(acc) | section: String.trim(rest)}

  defp parse_line("Scope:" <> _ = line, %{cur: nil} = acc), do: %{acc | scope: String.trim(line)}

  defp parse_line(line, acc), do: add(acc, line)

  defp add(%{cur: nil} = acc, _line), do: acc
  defp add(%{cur: cur} = acc, line), do: %{acc | cur: %{cur | body: [line | cur.body]}}

  defp flush(%{cur: nil} = acc), do: acc

  defp flush(%{cur: cur, rules: rules} = acc) do
    body = cur.body |> Enum.reverse() |> trim_blanks()
    %{acc | cur: nil, rules: [%{cur | body: body} | rules]}
  end

  defp trim_blanks(lines) do
    lines
    |> Enum.drop_while(&(String.trim(&1) == ""))
    |> Enum.reverse()
    |> Enum.drop_while(&(String.trim(&1) == ""))
    |> Enum.reverse()
  end

  # ---------------------------------------------------------------- slug
  def slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
  end

  # ---------------------------------------------------------------- inline + block render
  def inline(s) do
    s
    |> esc()
    |> then(&Regex.replace(~r/\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)/, &1,
        ~S(<a href="\2" target="_blank" rel="noopener">\1</a>)))
    |> then(&Regex.replace(~r/\*\*([^*]+)\*\*/, &1, ~S(<strong>\1</strong>)))
    |> then(&Regex.replace(~r/`([^`]+)`/, &1, ~S(<code>\1</code>)))
  end

  defp esc(s),
    do: s |> String.replace("&", "&amp;") |> String.replace("<", "&lt;") |> String.replace(">", "&gt;")

  # Render the supported subset: paragraphs, `- ` bullet lists, and ```elixir fences.
  def render_body(lines) do
    {blocks, cur, _fence} = Enum.reduce(lines, {[], nil, false}, &block_step/2)

    cur
    |> flush_block(blocks)
    |> Enum.reverse()
    |> Enum.map(&render_block/1)
    |> Enum.join("\n")
  end

  defp block_step(line, {blocks, cur, fence}) do
    cond do
      String.starts_with?(line, "```") and fence ->
        {:code_lines, code_lines} = cur
        {[{:code, Enum.reverse(code_lines)} | blocks], nil, false}

      String.starts_with?(line, "```") ->
        {flush_block(cur, blocks), {:code_lines, []}, true}

      fence ->
        {:code_lines, code_lines} = cur
        {blocks, {:code_lines, [line | code_lines]}, true}

      String.trim(line) == "" ->
        {flush_block(cur, blocks), nil, false}

      Regex.match?(~r/^\s*[-*] /, line) ->
        item = strip_bullet(line)
        case cur do
          {:bullets, items} -> {blocks, {:bullets, [item | items]}, false}
          _ -> {flush_block(cur, blocks), {:bullets, [item]}, false}
        end

      true ->
        case cur do
          {:para, lines} -> {blocks, {:para, [line | lines]}, false}
          _ -> {flush_block(cur, blocks), {:para, [line]}, false}
        end
    end
  end

  defp flush_block(nil, blocks), do: blocks
  defp flush_block({:para, lines}, blocks), do: [{:para, Enum.reverse(lines)} | blocks]
  defp flush_block({:bullets, items}, blocks), do: [{:bullets, Enum.reverse(items)} | blocks]
  defp flush_block({:code_lines, lines}, blocks), do: [{:code, Enum.reverse(lines)} | blocks]

  defp strip_bullet(line), do: Regex.replace(~r/^\s*[-*] /, line, "")

  defp render_block({:para, lines}), do: "<p>" <> inline(Enum.join(lines, " ")) <> "</p>"

  defp render_block({:bullets, items}) do
    lis = items |> Enum.map(&("<li>" <> inline(&1) <> "</li>")) |> Enum.join("")
    "<ul>#{lis}</ul>"
  end

  defp render_block({:code, lines}),
    do: "<pre><code>" <> esc(Enum.join(lines, "\n")) <> "</code></pre>"

  # ---------------------------------------------------------------- store (JSON)
  def load_store(path) do
    path
    |> File.read!()
    |> :json.decode()
  end

  def json_encode(term), do: term |> :json.encode() |> IO.iodata_to_binary()

  # A schema-3 store is %{"rules" => [%{"name", "tags", "references"}, ...]}. These give the
  # per-rule entries as a list, and as a map keyed by the slug of each entry's name.
  def store_rules(path), do: load_store(path)["rules"]
  def store_by_slug(path), do: store_rules(path) |> Map.new(&{slugify(&1["name"]), &1})

  # ---------------------------------------------------------------- validation
  # Returns {parsed_slugs, store_slugs, [error_string]}
  def validate_doc(doc_path) do
    parsed = parse_doc(doc_path)
    references_path = store_path(doc_path)
    errors = []

    {store_slug_list, errors} =
      if File.exists?(references_path) do
        {references_path |> store_rules() |> Enum.map(&slugify(&1["name"])), errors}
      else
        {[], ["#{references_path}: references store missing" | errors]}
      end

    store_slugs = MapSet.new(store_slug_list)
    store_dupes = store_slug_list -- Enum.uniq(store_slug_list)

    rule_slugs = Enum.map(parsed.rules, & &1.slug)
    dupes = rule_slugs -- Enum.uniq(rule_slugs)

    parsed_set = MapSet.new(rule_slugs)
    missing = MapSet.to_list(MapSet.difference(parsed_set, store_slugs))
    extra = MapSet.to_list(MapSet.difference(store_slugs, parsed_set))

    errors =
      errors
      |> add_error(dupes != [], "#{doc_path}: duplicate rule slugs #{inspect(Enum.uniq(dupes))}")
      |> add_error(store_dupes != [], "#{Path.basename(references_path)}: duplicate rule names #{inspect(Enum.uniq(store_dupes))}")
      |> add_error(missing != [], "#{doc_path}: rules with no references entry: #{inspect(missing)}")
      |> add_error(extra != [], "#{Path.basename(references_path)}: references entries with no rule: #{inspect(extra)}")

    errors =
      Enum.reduce(parsed.rules, errors, fn rule, acc ->
        cond do
          rule.section == nil -> ["#{doc_path}: rule '#{rule.name}' is not under a ## section" | acc]
          rule.name == "" -> ["#{doc_path}: empty rule heading" | acc]
          true -> acc
        end
      end)

    {parsed, Enum.reverse(errors)}
  end

  defp add_error(errors, false, _message), do: errors
  defp add_error(errors, true, message), do: [message | errors]
end

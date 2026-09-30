Code.require_file("lib/standards.ex", __DIR__)

defmodule BuildDashboard do
  @out "index.html"
  @asset_dir "assets"

  def run do
    {docs_data, errors} =
      Enum.reduce(Standards.docs(), {[], []}, fn path, {acc, errors} ->
        {parsed, doc_errors} = Standards.validate_doc(path)
        references_path = Standards.store_path(path)

        store =
          if File.exists?(references_path),
            do: Standards.store_by_slug(references_path),
            else: %{}

        rules =
          Enum.map(parsed.rules, fn rule ->
            entry = Map.get(store, rule.slug, %{})

            %{
              "name" => rule.name,
              "section" => rule.section,
              "tags" => Map.get(entry, "tags", []),
              "body_html" => Standards.render_body(rule.body),
              "text" => plain_text(rule),
              "references" => Map.get(entry, "references", [])
            }
          end)

        {[%{"title" => parsed.title, "doc" => path, "rules" => rules} | acc], errors ++ doc_errors}
      end)

    unless errors == [] do
      IO.puts(:stderr, "dashboard build FAILED (rules and references are not 1:1, or format errors):")
      Enum.each(errors, &IO.puts(:stderr, "  - #{&1}"))
      System.halt(1)
    end

    data = %{"generated_at" => Date.to_iso8601(Date.utc_today()), "docs" => Enum.reverse(docs_data)}
    payload = data |> Standards.json_encode() |> String.replace("</", "<\\/")

    html =
      template()
      |> String.replace("__CARET_DOWN__", svg_url("#{@asset_dir}/caret-down.svg"))
      |> String.replace("__CARET_UP__", svg_url("#{@asset_dir}/caret-up.svg"))
      |> String.replace("__INLINED_DATA__", payload)

    File.write!(@out, html)
    nrules = Enum.sum(Enum.map(docs_data, &length(&1["rules"])))
    kb = div(byte_size(html), 1024)
    IO.puts("dashboard: #{@out} <- #{length(docs_data)} docs, #{nrules} rules (#{kb} KB, self-contained)")
  end

  defp plain_text(rule) do
    [rule.name | rule.body]
    |> Enum.join(" ")
    |> String.replace(~r/[`*]/, "")
    |> String.replace(~r/\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)/, "\\1")
  end

  defp svg_url(path) do
    svg = path |> File.read!() |> String.split() |> Enum.join(" ")
    ~s|url("data:image/svg+xml,| <> URI.encode(svg, &URI.char_unreserved?/1) <> ~s|")|
  end

  defp template, do: File.read!("#{@asset_dir}/dashboard_template.html")
end

BuildDashboard.run()

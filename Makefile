.PHONY: dashboard dashboard-build dashboard-serve lint index index-check

# Lint the standards docs: strict format and the 1:1 rule<->references contract.
lint:
	@elixir scripts/lint.exs

# Regenerate the standards/elixir/README.md index (topic docs -> rule names by section).
index:
	@elixir scripts/build_index.exs

# CI check: fail if the committed index is stale. Regenerate, then diff against HEAD.
index-check: index
	@git diff --exit-code -- standards/elixir/README.md \
		|| ( echo "standards/elixir/README.md is stale; run 'make index' and commit it."; exit 1 )

# Regenerate index.html from the docs + references stores. Fails on any format or
# 1:1 contract violation (this is what CI runs).
dashboard-build:
	@elixir scripts/build_dashboard.exs

# Build the self-contained dashboard and open it in a browser (standalone file:// view).
# This is the one-line local command: `make dashboard`.
dashboard: dashboard-build
	@open index.html 2>/dev/null || xdg-open index.html 2>/dev/null || \
		echo "Built index.html. Open it in your browser."

# Serve the dashboard over http, then open it. Ctrl-C to stop the server.
dashboard-serve: dashboard-build
	@echo "Serving on http://localhost:8777/ (Ctrl-C to stop)"
	@( sleep 1 ; open http://localhost:8777/ 2>/dev/null || xdg-open http://localhost:8777/ 2>/dev/null || true ) &
	@python3 -m http.server 8777

check: lint test

lint:
	nix run .#lint

test:
	nix run .#test

demo:
	nix run .#demo

dev:
	nix develop

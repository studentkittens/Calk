coffee:
	coffee -c snobaer/static/js/*.coffee
	coffeelint snobaer/static/js/*.coffee

coffees:
	while true; do \
		coffee -c snobaer/static/js/*.coffee; \
		coffeelint snobaer/static/js/*.coffee; \
		sleep 1; \
	done; \
	true

wind:
	python3 snobaer/__init__.py

doc:
	pandoc docs/documentation.md -N --filter pandoc-fignos -o documentation.pdf

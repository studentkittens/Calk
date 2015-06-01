coffee:
	coffee -c snobaer/static/js/*.coffee
	coffeelint snobaer/static/js/*.coffee

starbucks:
	while true; do \
		coffee -c snobaer/static/js/*.coffee; \
		coffeelint snobaer/static/js/*.coffee; \
		sleep 1; \
	done; \
	true

wind:
	python3 snobaer/__init__.py

comedy:
	pandoc docs/documentation.md -B title.tex -H header.tex -N --filter pandoc-fignos -o documentation.pdf -V lang=ngerman

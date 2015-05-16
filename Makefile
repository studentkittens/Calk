coffee:
	coffee -c snobaer/static/js/*.coffee
	coffeelint snobaer/static/js/*.coffee

wind:
	python3 snobaer/__init__.py

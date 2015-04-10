coffee:
	coffee -c snobaer/static/*.coffee
	coffeelint snobaer/static/*.coffee

wind:
	python3 snobaer/__init__.py

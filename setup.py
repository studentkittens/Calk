from setuptools import setup

setup(
    name='snobaer',
    version='0.1',
    description='A neat web mpd client',
    url='http://github.com/studentkittens/snobaer',
    author='Christopher Pahl',
    author_email='sahib@online.de',
    long_description=open('README.rst').read(),
    license='GPLv3',
    packages=['snobaer'],
    package_data={'snobaer': [
        'templates/*',
        'static/js/*',
        'static/css/*',
        'static/fonts/*',
    ]}
)

# encoding: utf-8

# Stdlib:
import re
import random
random.seed(0xdeadbeef)

# External:
from nose import with_setup

# Internal:
from tests.utils import *
from gi.repository import Moose, GLib

# External:
from faker import Faker
fake = Faker()


TYPES = {
    's': lambda: fake.name(),
    'b': lambda: random.choice([True, False]),
    'd': lambda: random.randint(-2 ** 31, 2 ** 31),
    'i': lambda: random.random() * 42 - 23
}


def generate_fuzzy_commands():
    pattern = re.compile('\(s(.*)\)')
    handler = Moose.HandlerIter.init()

    while handler.next():
        data_type = pattern.match(handler.format).group(1)
        assert data_type  # Should not be empty.

        data_args = [TYPES[type_id]() for type_id in data_type]
        yield GLib.Variant(
            handler.format, tuple([handler.command] + data_args)
        )


@with_setup(setup_client, teardown_client)
def test_simple():
    elk = client()
    for variant in generate_fuzzy_commands():
        elk.send_variant(variant)

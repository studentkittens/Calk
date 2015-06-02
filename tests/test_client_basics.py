# encoding: utf-8

# External:
from gi.repository import Moose
from nose import with_setup

# Internal:
from tests.utils import *


@with_setup(setup_client, teardown_client)
def test_simple():
    c = client()
    id_ = c.send_single('next')

if __name__ == '__main__':
    unittest.main()

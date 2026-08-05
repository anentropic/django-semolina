"""Basic tests for django_semolina."""

import django_semolina


def test_import():
    assert hasattr(django_semolina, "__all__")

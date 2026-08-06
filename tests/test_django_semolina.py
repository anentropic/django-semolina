"""Basic tests for django_semolina."""

from django.apps import apps

import django_semolina


def test_import():
    assert hasattr(django_semolina, "__all__")


def test_installed_as_django_app():
    """The package boots as a Django app under the Django version under test."""
    assert apps.is_installed("django_semolina")


def test_semolina_is_importable():
    """The Semolina dependency resolves alongside Django."""
    import semolina

    assert semolina.__name__ == "semolina"

"""
Minimal Django settings for the django-semolina test suite.

Not a template for user projects — just enough for Django to boot the app
registry so tests can exercise the integration under each supported version.
"""

SECRET_KEY = "not-a-secret-only-used-by-the-test-suite"  # noqa: S105

INSTALLED_APPS = [
    "django_semolina",
]

# Semolina talks to the warehouse through its own pools, not the Django ORM,
# so the test suite needs no Django database.
DATABASES = {}

USE_TZ = True

"""Requestor notification routing and admin announcement audience."""

import pytest
from fastapi import HTTPException

from app.api.routes import admin_integrations as integrations
from app.models.enums import RoleName
from app.services.notification_events import gallery_batch_should_send


def test_announcement_audience_both():
    roles = integrations._announcement_audience_roles("both")
    assert RoleName.MEMBER in roles
    assert RoleName.ORGANIZATION in roles


def test_announcement_audience_requestor_only():
    roles = integrations._announcement_audience_roles("requestor")
    assert roles == (RoleName.ORGANIZATION,)


def test_announcement_audience_invalid():
    with pytest.raises(HTTPException) as exc:
        integrations._announcement_audience_roles("admins")
    assert exc.value.status_code == 400


def test_gallery_batch_threshold():
    assert gallery_batch_should_send(5, 0.0) is True
    assert gallery_batch_should_send(4, 0.0) is False


def test_gallery_batch_debounce():
    assert gallery_batch_should_send(2, 31.0) is True
    assert gallery_batch_should_send(2, 10.0) is False
    assert gallery_batch_should_send(0, 60.0) is False


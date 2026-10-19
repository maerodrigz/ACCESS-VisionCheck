"""Requestor notification routing and admin announcement audience."""

from app.api.routes import admin_integrations as integrations
from app.models.enums import RoleName
from app.services.notification_events import gallery_batch_should_send


def test_announcement_audience_is_members_only():
    assert integrations._announcement_audience_roles("both") == (RoleName.MEMBER,)
    assert integrations._announcement_audience_roles("requestor") == (RoleName.MEMBER,)
    assert integrations._announcement_audience_roles("member") == (RoleName.MEMBER,)
    assert integrations._announcement_audience_roles(None) == (RoleName.MEMBER,)


def test_gallery_batch_threshold():
    assert gallery_batch_should_send(5, 0.0) is True
    assert gallery_batch_should_send(4, 0.0) is False


def test_gallery_batch_debounce():
    assert gallery_batch_should_send(2, 31.0) is True
    assert gallery_batch_should_send(2, 10.0) is False
    assert gallery_batch_should_send(0, 60.0) is False


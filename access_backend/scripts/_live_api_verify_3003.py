#!/usr/bin/env python3
"""Live API verification on 127.0.0.1:3003 (access_waverep_test). Prints TSV: id\\tPASS|FAIL|BLOCKED\\tdetail"""

from __future__ import annotations

import os
import sys
import uuid
from datetime import date, timedelta
from pathlib import Path

import httpx

API = os.environ.get("VERIFY_API_BASE", "http://127.0.0.1:3003/api").rstrip("/")
ADMIN_EMAIL = os.environ.get("SMOKE_ADMIN_EMAIL", "admin@access.edu")
ADMIN_PASSWORD = os.environ.get("SMOKE_ADMIN_PASSWORD", "admin123")
ORG_EMAIL = os.environ.get("SMOKE_ORG_EMAIL", "qa-org-qa-2026-10-23-f8011b5d@example.com")
ORG_PASSWORD = os.environ.get("SMOKE_ORG_PASSWORD", "")
ORG_B_EMAIL = os.environ.get("SMOKE_ORG_B_EMAIL", "")
ORG_B_PASSWORD = os.environ.get("SMOKE_ORG_B_PASSWORD", "")
MEMBER_EMAIL = os.environ.get("SMOKE_MEMBER_EMAIL", "qa-member-qa-2026-10-23-f8011b5d@example.com")
MEMBER_PASSWORD = os.environ.get("SMOKE_MEMBER_PASSWORD", "")

_RUN = uuid.uuid4().hex[:8]
TAG = f"LIVE-{date.today().isoformat()}-{_RUN}"
# Unique day/time per run to avoid campus schedule overlap on waverep_test.
_slot = int(_RUN[:4], 16)
DAY = (date.today() + timedelta(days=90 + (_slot % 120))).isoformat()
_START_H = 6 + (_slot % 12)
_START_M = (_slot >> 4) % 4 * 15
_END_H = min(_START_H + 2, 22)
_START = f"{_START_H:02d}:{_START_M:02d}"
_END = f"{_END_H:02d}:{(_START_M + 30) % 60:02d}"
_REJECT_START = f"{min(_START_H + 4, 20):02d}:00"
_REJECT_END = f"{min(_START_H + 6, 21):02d}:00"


def emit(tid: str, status: str, detail: str = "") -> None:
    print(f"{tid}\t{status}\t{detail[:400]}", flush=True)


def login(client: httpx.Client, email: str, password: str) -> str | None:
    r = client.post(f"{API}/auth/login", json={"email": email, "password": password})
    if r.status_code != 200:
        return None
    return r.json().get("token")


def count_events_for_request(client: httpx.Client, headers: dict, request_id: int) -> int:
    r = client.get(f"{API}/admin/events", headers=headers)
    if r.status_code != 200:
        return -1
    n = 0
    for ev in r.json():
        rid = ev.get("request_id") or ev.get("documentation_request_id")
        if rid is not None and int(rid) == int(request_id):
            n += 1
    return n


def main() -> int:
    fails = 0
    if not ORG_PASSWORD or not MEMBER_PASSWORD:
        emit("PRE", "BLOCKED", "Set SMOKE_ORG_PASSWORD and SMOKE_MEMBER_PASSWORD in session env")
        return 2

    with httpx.Client(timeout=60.0) as client:
        h = client.get(f"{API}/health")
        emit("API-001", "PASS" if h.status_code == 200 else "FAIL", f"health status={h.status_code}")

        admin_token = login(client, ADMIN_EMAIL, ADMIN_PASSWORD)
        org_token = login(client, ORG_EMAIL, ORG_PASSWORD)
        mem_token = login(client, MEMBER_EMAIL, MEMBER_PASSWORD)
        emit("API-002", "PASS" if admin_token else "FAIL", "admin login")
        emit("API-003", "PASS" if org_token else "FAIL", "org login")
        emit("API-004", "PASS" if mem_token else "FAIL", "member login")
        if not (admin_token and org_token and mem_token):
            return 1

        ah = {"Authorization": f"Bearer {admin_token}"}
        oh = {"Authorization": f"Bearer {org_token}"}
        mh = {"Authorization": f"Bearer {mem_token}"}

        body = {
            "title": f"Live Verify {TAG}",
            "description": "Isolated live API calendar+duplicate test.",
            "event_date": DAY,
            "venue": "QA Hall",
            "start_time": _START,
            "end_time": _END,
            "requirements": "photo",
        }
        r1 = client.post(f"{API}/service-requests", headers=oh, json=body)
        if r1.status_code != 200:
            emit("CAL-A", "FAIL", f"create status={r1.status_code} {r1.text[:120]}")
            return 1
        req_id = r1.json().get("id")
        st = (r1.json().get("status") or "").lower()
        emit("CAL-A", "PASS" if st == "pending" else "FAIL", f"submit pending id={req_id} status={st}")

        notif_before = len(client.get(f"{API}/notifications", headers=oh).json())

        r_dup = client.post(f"{API}/service-requests", headers=oh, json=body)
        dup_id = r_dup.json().get("id") if r_dup.status_code == 200 else None
        emit(
            "DUP-A",
            "PASS" if r_dup.status_code == 200 and dup_id == req_id else "FAIL",
            f"dup status={r_dup.status_code} id={dup_id} expect={req_id}",
        )

        notif_after = len(client.get(f"{API}/notifications", headers=oh).json())
        emit(
            "DUP-B",
            "PASS" if notif_after == notif_before else "FAIL",
            f"requestor notifications before={notif_before} after={notif_after}",
        )

        body2 = {**body, "title": f"Overlap Other {TAG}"}
        r_overlap = client.post(f"{API}/service-requests", headers=oh, json=body2)
        emit(
            "DUP-C",
            "PASS" if r_overlap.status_code == 400 else "FAIL",
            f"overlap different title status={r_overlap.status_code}",
        )

        ev_before = count_events_for_request(client, ah, req_id)
        emit("CAL-B", "PASS" if ev_before == 0 else "FAIL", f"events before approve count={ev_before}")

        appr = client.patch(f"{API}/service-requests/{req_id}", headers=ah, json={"status": "Approved"})
        emit("CAL-C", "PASS" if appr.status_code == 200 else "FAIL", f"approve status={appr.status_code}")

        ev_after = count_events_for_request(client, ah, req_id)
        emit("CAL-D", "PASS" if ev_after == 1 else "FAIL", f"events after approve count={ev_after}")

        org_events = client.get(f"{API}/events", headers=oh, params={"scope": "my-requests"})
        org_has = any(int(e.get("request_id") or 0) == int(req_id) for e in org_events.json()) if org_events.status_code == 200 else False
        emit(
            "CAL-E",
            "PASS" if org_events.status_code == 200 and org_has else "FAIL",
            f"requestor events has request before assign={org_has}",
        )

        admin_events = client.get(f"{API}/admin/events", headers=ah)
        admin_has = any(int(e.get("request_id") or 0) == int(req_id) for e in admin_events.json()) if admin_events.status_code == 200 else False
        emit("CAL-F", "PASS" if admin_has else "FAIL", f"admin events has approved event={admin_has}")

        main_event_id = None
        if admin_events.status_code == 200:
            main_event_id = next(
                (
                    int(e.get("id"))
                    for e in admin_events.json()
                    if int(e.get("request_id") or 0) == int(req_id)
                ),
                None,
            )
        if main_event_id:
            pre_assign_detail = client.get(f"{API}/events/{main_event_id}", headers=mh)
            pre_body = pre_assign_detail.json() if pre_assign_detail.status_code == 200 else {}
            pre_redacted = "assignment_id" not in pre_body
            emit(
                "OPT-C4",
                "PASS" if pre_assign_detail.status_code == 200 and pre_redacted else "FAIL",
                f"pre-assign member detail redacted={pre_redacted}",
            )

        users = client.get(f"{API}/users", headers=ah).json()
        member_id = next((u.get("user_id") for u in users if (u.get("email") or "").lower() == MEMBER_EMAIL.lower()), None)
        assign = client.post(
            f"{API}/admin/service-requests/{req_id}/assign",
            headers=ah,
            json={"member_id": member_id, "task_role": "photographer"},
        )
        emit("CAL-G", "PASS" if assign.status_code == 200 else "FAIL", f"assign status={assign.status_code}")

        ev_post = count_events_for_request(client, ah, req_id)
        emit("CAL-H", "PASS" if ev_post == 1 else "FAIL", f"events after assign count={ev_post}")

        mem_assign = client.get(f"{API}/events", headers=mh, params={"scope": "assignments"})
        mem_has = any(int(e.get("request_id") or 0) == int(req_id) for e in mem_assign.json()) if mem_assign.status_code == 200 else False
        emit("CAL-I", "PASS" if mem_assign.status_code == 200 and mem_has else "FAIL", f"member assignments scope sees event={mem_has}")

        mem_campus = client.get(f"{API}/events", headers=mh, params={"scope": "campus"})
        campus_sample = mem_campus.json()[0] if mem_campus.status_code == 200 and mem_campus.json() else {}
        redacted = "description" not in campus_sample and "documentation_team" not in campus_sample
        emit("OPT-C", "PASS" if mem_campus.status_code == 200 and redacted else "FAIL", f"campus redacted={redacted}")

        # Reject path on overlap request if created - use separate small request
        body3 = {
            **body,
            "title": f"Reject Path {TAG}",
            "start_time": _REJECT_START,
            "end_time": _REJECT_END,
        }
        r3 = client.post(f"{API}/service-requests", headers=oh, json=body3)
        if r3.status_code == 200:
            rid3 = r3.json()["id"]
            client.patch(f"{API}/service-requests/{rid3}", headers=ah, json={"status": "Approved"})
            client.patch(
                f"{API}/service-requests/{rid3}",
                headers=ah,
                json={"status": "Rejected", "rejection_reason": "QA reject path test reason"},
            )
            org_ev = client.get(f"{API}/events", headers=oh, params={"scope": "my-requests"}).json()
            hidden = not any(int(e.get("request_id") or 0) == int(rid3) for e in org_ev)
            emit("CAL-J", "PASS" if hidden else "FAIL", f"rejected request absent from requestor events={hidden}")
        else:
            emit("CAL-J", "FAIL", f"reject setup create status={r3.status_code}")

        if ORG_B_EMAIL and ORG_B_PASSWORD:
            org_b_token = login(client, ORG_B_EMAIL, ORG_B_PASSWORD)
            if org_b_token:
                bh = {"Authorization": f"Bearer {org_b_token}"}
                list_b = client.get(f"{API}/service-requests", headers=bh).json()
                leak = any(int(r.get("id") or 0) == int(req_id) for r in list_b)
                emit("ACL-001", "PASS" if not leak else "FAIL", f"org B sees org A request={leak}")
            else:
                emit("ACL-001", "BLOCKED", "org B login failed")
        else:
            emit("ACL-001", "BLOCKED", "No second org account configured")

        # Member sees unrelated approved events?
        campus_count = len(mem_campus.json()) if mem_campus.status_code == 200 else 0
        assign_count = len(mem_assign.json()) if mem_assign.status_code == 200 else 0
        emit(
            "ACL-002",
            "PASS" if mem_campus.status_code == 200 else "FAIL",
            f"campus_events={campus_count} assignment_events={assign_count} (scoped lists)",
        )

        unscoped = client.get(f"{API}/events", headers=mh)
        emit("OPT-C2", "PASS" if unscoped.status_code == 422 else "FAIL", f"unscoped status={unscoped.status_code}")

        bypass = client.get(f"{API}/events", headers=mh, params={"scope": "campus", "member_id": 1})
        emit("OPT-C3", "PASS" if bypass.status_code == 422 else "FAIL", f"member_id bypass status={bypass.status_code}")

        post_assign_detail = (
            client.get(f"{API}/events/{main_event_id}", headers=mh)
            if main_event_id
            else None
        )
        if post_assign_detail is not None:
            post_body = post_assign_detail.json() if post_assign_detail.status_code == 200 else {}
            has_assignment = post_body.get("assignment_id") is not None
            emit(
                "OPT-C5",
                "PASS" if post_assign_detail.status_code == 200 and has_assignment else "FAIL",
                f"post-assign member detail has assignment={has_assignment}",
            )

        emit("QA-TAG", "PASS", f"tag={TAG} req_main={req_id}")

    return fails


if __name__ == "__main__":
    raise SystemExit(main())

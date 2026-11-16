# UAT participant instructions

Thank you for helping test **ACCESS VisionCheck**. This is **acceptance testing**, not training. Please follow the steps and record **PASS** or **FAIL** honestly.

## Before you start

1. Use only the **UAT** URLs and accounts your facilitator gave you.
2. **Admin Web:** open `http://127.0.0.1:5175` (facilitator must start the server).
3. **Mobile app:** use the build or `flutter run` command from the facilitator. On a USB phone, backend URL is usually `http://127.0.0.1:3005` with port reverse enabled.
4. Use **synthetic** event names (for example “UAT Photo Club 2026”) and test photos you are allowed to upload.
5. Do **not** expect real email, SMS, Facebook posts, or push notifications during UAT unless the facilitator says otherwise.

## Your role

| If you are… | Use… | Main app |
|-------------|------|----------|
| Administrator | Admin account | Web browser (Chrome/Edge) |
| Member (documenter) | Member 1 or Member 2 | Flutter mobile app |
| Requestor (organization) | Requestor account | Flutter mobile app |

## How to test

1. Open **`UAT_Test_Scenarios.md`** and find scenarios for your role.
2. Perform each **Task** in order.
3. Compare what you see to **Expected result**.
4. Mark **Actual result**, **PASS/FAIL**, and **Remarks** in **`UAT_Results_Template.md`** (copy per tester).
5. Log any defect in **`UAT_Issue_Log.md`** with steps to reproduce.

## Tips

- If login fails on mobile, ask the facilitator to check **Backend URL** (Account settings on phone) and that the UAT API is running.
- If Admin Web shows errors, confirm the address is **5175**, not 5173.
- Take a screenshot for any **FAIL** (no passwords in the screenshot).
- If you are stuck, write **BLOCKED** in remarks and describe what blocked you.

## What we are not testing in this UAT

- Production data or real Facebook pages
- Full penetration / security audit
- Load testing with hundreds of users

Your feedback on clarity, workflow, and bugs is enough.

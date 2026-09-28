from fastapi import APIRouter



from app.api.routes import (

    admin,
    admin_integrations,
    admin_members,
    admin_registrations,
    branding,

    archives,

    auth,

    comments,

    documentation_requests,

    evaluations,

    event_media,

    events,

    facebook,

    feedback,

    gallery,

    health,

    media,

    member,
    profile,

    notifications,

    announcements,

    rankings,

    system_settings,

    tasks,

    users,

    ai_assist,

)



api_router = APIRouter(prefix="/api")



api_router.include_router(health.router)
api_router.include_router(branding.router)

api_router.include_router(auth.router)

api_router.include_router(users.router)

api_router.include_router(member.router)
api_router.include_router(profile.router)

api_router.include_router(rankings.router)

api_router.include_router(admin.router)
api_router.include_router(event_media.router)
api_router.include_router(admin_members.router)
api_router.include_router(admin_registrations.router)
api_router.include_router(admin_integrations.router)
api_router.include_router(system_settings.router)

api_router.include_router(documentation_requests.router)

api_router.include_router(tasks.router)

api_router.include_router(events.router)

api_router.include_router(notifications.router)

api_router.include_router(announcements.router)

api_router.include_router(media.router)

api_router.include_router(gallery.router)

api_router.include_router(comments.router)

api_router.include_router(evaluations.router)

api_router.include_router(feedback.router)

api_router.include_router(facebook.router)

api_router.include_router(archives.router)

api_router.include_router(ai_assist.router)


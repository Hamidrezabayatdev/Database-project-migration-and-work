from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from psycopg2.extras import RealDictCursor
from jose import JWTError
import psycopg2

from database import get_db
from auth_utils import hash_password, verify_password, create_token, decode_token
from schemas import RegisterRequest, LoginRequest, ApplyRequest

app = FastAPI(title="Migration & Career Support System API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

security = HTTPBearer()


def _pg_error_msg(e: psycopg2.Error) -> str:
    """Extract the human-readable message from a PostgreSQL error."""
    if hasattr(e, "diag") and e.diag.message_primary:
        return e.diag.message_primary
    return str(e).split("\n")[0]


def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(security),
    conn=Depends(get_db),
):
    try:
        user_id = decode_token(creds.credentials)
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            "SELECT user_id, email, role FROM users WHERE user_id = %s AND is_active = TRUE",
            (user_id,),
        )
        user = cur.fetchone()

    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return dict(user)


# ─── AUTH ────────────────────────────────────────────────────────────────────

@app.post("/api/register", tags=["auth"])
def register(req: RegisterRequest, conn=Depends(get_db)):
    pwd_hash = hash_password(req.password)
    try:
        with conn.cursor() as cur:
            # Call our stored procedure — it raises on duplicate email
            cur.execute(
                "CALL sp_register_user(%s, %s, %s, %s, %s, NULL)",
                (req.email, pwd_hash, req.first_name, req.last_name, req.nationality_country_id),
            )
        conn.commit()
    except psycopg2.Error as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=_pg_error_msg(e))

    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("SELECT user_id, email FROM users WHERE email = %s", (req.email.lower(),))
        user = cur.fetchone()

    return {
        "access_token": create_token(user["user_id"]),
        "token_type": "bearer",
        "user_id": user["user_id"],
        "email": user["email"],
        "full_name": f"{req.first_name} {req.last_name}",
    }


@app.post("/api/login", tags=["auth"])
def login(req: LoginRequest, conn=Depends(get_db)):
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """SELECT u.user_id, u.email, u.password_hash,
                      up.first_name, up.last_name
               FROM users u
               JOIN user_profiles up ON up.user_id = u.user_id
               WHERE u.email = %s AND u.is_active = TRUE""",
            (req.email.lower(),),
        )
        user = cur.fetchone()

    if not user or not verify_password(req.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    return {
        "access_token": create_token(user["user_id"]),
        "token_type": "bearer",
        "user_id": user["user_id"],
        "email": user["email"],
        "full_name": f"{user['first_name']} {user['last_name']}",
    }


# ─── ME / DASHBOARD ──────────────────────────────────────────────────────────

@app.get("/api/me", tags=["profile"])
def get_me(current_user=Depends(get_current_user), conn=Depends(get_db)):
    uid = current_user["user_id"]
    with conn.cursor(cursor_factory=RealDictCursor) as cur:

        cur.execute(
            """SELECT fn_format_full_name(up.first_name, up.last_name) AS full_name,
                      up.profile_completeness_pct, up.bio,
                      cn.name AS nationality
               FROM user_profiles up
               LEFT JOIN countries cn ON cn.country_id = up.nationality_country_id
               WHERE up.user_id = %s""",
            (uid,),
        )
        profile = cur.fetchone()

        cur.execute(
            """SELECT ja.app_id, j.title AS job_title, c.name AS company,
                      ja.status, ja.match_score,
                      ja.applied_at::TEXT AS applied_at
               FROM job_applications ja
               JOIN jobs j ON j.job_id = ja.job_id
               JOIN companies c ON c.company_id = j.company_id
               WHERE ja.user_id = %s
               ORDER BY ja.applied_at DESC NULLS LAST""",
            (uid,),
        )
        applications = [dict(r) for r in cur.fetchall()]

        cur.execute(
            """SELECT notif_id, title, message, is_read, created_at::TEXT AS created_at
               FROM notifications WHERE user_id = %s
               ORDER BY created_at DESC LIMIT 5""",
            (uid,),
        )
        notifications = [dict(r) for r in cur.fetchall()]

    return {
        "profile": dict(profile) if profile else {},
        "applications": applications,
        "notifications": notifications,
    }


# ─── JOBS ────────────────────────────────────────────────────────────────────

@app.get("/api/jobs", tags=["jobs"])
def list_jobs(conn=Depends(get_db)):
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """SELECT j.job_id, j.title, c.name AS company,
                      i.name AS industry, co.name AS country, ci.name AS city,
                      j.employment_type, j.salary_min, j.salary_max, j.currency,
                      j.required_exp_years, j.closes_at::TEXT AS closes_at,
                      ARRAY_AGG(DISTINCT s.name)
                          FILTER (WHERE js.is_required = TRUE) AS required_skills
               FROM jobs j
               JOIN companies c    ON c.company_id  = j.company_id
               LEFT JOIN industries i  ON i.industry_id  = j.industry_id
               LEFT JOIN countries co  ON co.country_id  = j.country_id
               LEFT JOIN cities ci     ON ci.city_id     = j.city_id
               LEFT JOIN job_skills js ON js.job_id      = j.job_id
               LEFT JOIN skills s      ON s.skill_id     = js.skill_id
               WHERE j.status = 'active'
               GROUP BY j.job_id, c.name, i.name, co.name, ci.name
               ORDER BY j.created_at DESC"""
        )
        return [dict(r) for r in cur.fetchall()]


@app.get("/api/jobs/{job_id}", tags=["jobs"])
def get_job(job_id: int, conn=Depends(get_db)):
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """SELECT j.job_id, j.title, j.description, c.name AS company,
                      i.name AS industry, co.name AS country, ci.name AS city,
                      j.employment_type, j.salary_min, j.salary_max, j.currency,
                      j.required_exp_years, j.closes_at::TEXT AS closes_at
               FROM jobs j
               JOIN companies c    ON c.company_id = j.company_id
               LEFT JOIN industries i  ON i.industry_id = j.industry_id
               LEFT JOIN countries co  ON co.country_id = j.country_id
               LEFT JOIN cities ci     ON ci.city_id    = j.city_id
               WHERE j.job_id = %s""",
            (job_id,),
        )
        job = cur.fetchone()

    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """SELECT s.name, js.is_required, js.min_proficiency
               FROM job_skills js JOIN skills s ON s.skill_id = js.skill_id
               WHERE js.job_id = %s ORDER BY js.is_required DESC, s.name""",
            (job_id,),
        )
        skills = [dict(r) for r in cur.fetchall()]

    result = dict(job)
    result["skills"] = skills
    return result


@app.post("/api/jobs/{job_id}/apply", tags=["jobs"])
def apply_for_job(
    job_id: int,
    req: ApplyRequest,
    current_user=Depends(get_current_user),
    conn=Depends(get_db),
):
    uid = current_user["user_id"]
    try:
        with conn.cursor() as cur:
            cur.execute("CALL sp_apply_for_job(%s, %s, %s, NULL)", (uid, job_id, req.cover_letter))
        conn.commit()
    except psycopg2.Error as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=_pg_error_msg(e))

    return {"message": "Application submitted successfully!"}


# ─── REFERENCE DATA ──────────────────────────────────────────────────────────

@app.get("/api/countries", tags=["reference"])
def list_countries(conn=Depends(get_db)):
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("SELECT country_id, name FROM countries ORDER BY name")
        return [dict(r) for r in cur.fetchall()]

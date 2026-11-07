FROM python:3.14.10-slim-bookworm AS builder

WORKDIR /build
COPY app.py .
RUN python -m compileall -q -b app.py \
    && mkdir -p /out \
    && cp app.pyc /out/app.pyc

FROM python:3.14.10-slim-bookworm AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN groupadd --system --gid 10001 app \
    && useradd --system --uid 10001 --gid app --no-create-home \
        --home-dir /nonexistent --shell /usr/sbin/nologin app

WORKDIR /app
COPY --from=builder --chown=10001:10001 /out/app.pyc ./app.pyc
USER 10001:10001
EXPOSE 8080
ENTRYPOINT ["python", "-I", "-B", "/app/app.pyc"]

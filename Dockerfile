########################################
# First stage to building python wheel #
########################################
FROM debian:buster-slim as builder_wheel

# Configure python environnement
ENV PYTHONUNBUFFERED 1
ENV PYTHONDONTWRITEBYTECODE 1

# Install builder requirements
RUN --mount=type=cache,target=/var/cache/apt \
    rm /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && apt-get install -y --no-install-recommends gcc apt-file dpkg-dev fakeroot build-essential \
	devscripts debhelper python3 python3-dev python3-pip python3-wheel python3-setuptools libpq-dev python3-apt && \
    apt-get clean

# Build wheel
COPY ./requirements.d /requirements.d/
COPY ./requirements.txt /
RUN --mount=type=cache,target=/root/.cache/pip python3 -m pip wheel --wheel-dir /wheels -r requirements.txt

########################################
# Second stage to building final image #
########################################
FROM debian:buster-slim as django-api
# Retrieve from first stage precompiled python wheel distribution
# Deb packaging is not ready yet. If we only have ref to builder_wheels
# image, builder_deb image, the second stage, 
COPY --from=builder_wheel /wheels /wheels

# Configure python environnement
ENV PYTHONUNBUFFERED 1
ENV PYTHONDONTWRITEBYTECODE 1

RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-pip libpq5 && \
    pip3 install --no-cache /wheels/*.whl && \
    rm /wheels -rf && \
    apt-get remove -y python3-pip && \
    apt autoremove -y && \
    apt-get clean

# Copy django project
WORKDIR /app
COPY ./project ./project
COPY ./applications ./applications
COPY ./manage.py .

# Prepare execution
ENV APP_PATH /app
ENV PYTHONPATH "${PYTHONPATH}:/app/:/app/applications/"
ENTRYPOINT ["python3", "/app/manage.py"]
CMD ["help"]

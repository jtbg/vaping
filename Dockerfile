ARG build_packages=" \
    gcc g++ make file libc-dev libffi-dev curl openssl-dev make rust cargo rrdtool-dev \
    "
ARG runtime_packages="fping librrd \
    zeromq \
    "
# vaping extras to be installed
ARG vaping_extras=all

ARG poetry_pin=">=1,<=2"

FROM python:3.9-alpine as base

ARG runtime_packages
ARG virtual_env=/venv

ENV VIRTUAL_ENV="$virtual_env"
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# image that builds vaping and deps
FROM base as builder

ARG build_packages
ARG runtime_packages
ARG vaping_extras

RUN apk --update --no-cache add $build_packages $runtime_packages

# install poetry outside of the venv
RUN pip install --upgrade pip wheel
# alpine package is currently only in edge
RUN pip install "poetry$poetry_pin"

# Create a VENV
RUN python3 -m venv "$VIRTUAL_ENV"

WORKDIR /src/vaping

COPY Ctl/VERSION Ctl/
COPY pyproject.toml poetry.lock ./
COPY examples examples
COPY src src
COPY tests tests

# Need to upgrade pip and wheel within Poetry for all its installs
RUN poetry run pip install --upgrade pip wheel
RUN poetry install --no-dev -E $vaping_extras

# TODO testing stage in container for package deps, etc

# final running image
FROM base

ARG runtime_packages
ARG vaping_home=/home/vaping/examples/standalone_dns/
ARG vaping_uid=1000

ENV VAPING_HOME=$vaping_home

RUN apk --update --no-cache add $runtime_packages \
      && rm -rf /var/cache/apk/*

COPY --from=builder "$VIRTUAL_ENV" "$VIRTUAL_ENV"

RUN adduser -Du $vaping_uid vaping

USER vaping
WORKDIR /home/vaping
COPY --from=builder /src/vaping/examples examples/

EXPOSE 7021

# The process just silently exits without --debug in docker.
CMD ["vaping", "--verbose", "--debug", "start"]
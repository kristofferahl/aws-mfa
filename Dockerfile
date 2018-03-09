FROM alpine:3.6
MAINTAINER kristofferahl <mail@77dynamite.com>

ARG AWS_CLI_VERSION=1.14.5

RUN apk -v --update add \
        bash \
        python \
        py-pip \
        groff \
        less \
        mailcap \
        jq \
        && \
    pip install --upgrade awscli==${AWS_CLI_VERSION} s3cmd==2.0.1 python-magic && \
    apk -v --purge del py-pip && \
    rm /var/cache/apk/*

VOLUME /root/.aws
VOLUME /work

WORKDIR /work
COPY . /work

ENV AWS_MFA_ACCESS_KEY_ID=
ENV AWS_MFA_SECRET_ACCESS_KEY=
ENV AWS_MFA_DEFAULT_REGION=us-east-1
ENV AWS_MFA_DEVICE_ID=
ENV AWS_MFA_TOKEN_CODE=

ENTRYPOINT ["/work/entrypoint"]

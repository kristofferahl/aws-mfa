FROM alpine:3.6
LABEL maintainer="kristofferahl <mail@77dynamite.com>"

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

VOLUME /work
COPY . /var/lib/aws-mfa/
WORKDIR /var/lib/aws-mfa/

ENV AWS_MFA_ACCESS_KEY_ID=
ENV AWS_MFA_SECRET_ACCESS_KEY=
ENV AWS_MFA_DEFAULT_REGION=
ENV AWS_MFA_DEVICE_ID=
ENV AWS_MFA_TOKEN_CODE=
ENV AWS_MFA_SESSION_FILE=/work/.aws-session

ENTRYPOINT ["./entrypoint"]

ARG BUILD_FROM
FROM $BUILD_FROM

ARG BUILD_ARCH
ARG FRP_VERSION

COPY bootstrap.sh /
COPY run.sh /
COPY frpc.toml /frpc.toml.example
COPY www/ /www/

RUN chmod a+x /bootstrap.sh
RUN chmod a+x /run.sh
RUN chmod a+x /www/handler.sh

RUN /bootstrap.sh $BUILD_ARCH $FRP_VERSION

CMD ["/run.sh"]

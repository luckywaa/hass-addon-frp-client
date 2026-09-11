ARG BUILD_FROM
FROM $BUILD_FROM

COPY run.sh /
COPY frpc.toml /frpc.toml.example
COPY www/ /www/

RUN chmod a+x /run.sh
RUN chmod a+x /www/handler.sh
RUN chmod a+x /www/dl.sh

CMD ["/run.sh"]

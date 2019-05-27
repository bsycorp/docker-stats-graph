FROM bitnami/minideb:stretch
ENV TINI_VERSION v0.18.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini
ENTRYPOINT ["/tini", "--"]
RUN install_packages curl jq socat zip gnuplot
ADD . /
CMD ["/start.sh"]

FROM bitnami/minideb:stretch
RUN install_packages curl jq python zip gnuplot
ADD . /
ENTRYPOINT ["/start.sh"]
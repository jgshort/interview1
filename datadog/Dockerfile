FROM datadog/agent:7

ENV DD_LOGS_ENABLED=true
ENV DD_APM_ENABLED=true
ENV DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=true
ENV DD_DOGSTATSD_NON_LOCAL_TRAFFIC=true
ENV DD_APM_NON_LOCAL_TRAFFIC=true
ENV DD_BIND_HOST=::1

ARG DD_API_KEY
ARG DD_SITE
ARG DD_HOSTNAME

COPY datadog.yaml /etc/datadog-agent/datadog.yaml
COPY syslog.yaml /etc/datadog-agent/conf.d/syslog.d/
COPY conf.yaml /etc/datadog-agent/conf.d/http_check.d/

EXPOSE 8125/udp
EXPOSE 8126
EXPOSE 514/udp


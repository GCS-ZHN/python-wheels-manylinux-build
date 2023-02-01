FROM quay.io/pypa/manylinux2014_x86_64

ENV PLAT manylinux2014_x86_64
RUN yum -y remove git && \
    yum -y remove git-* && \
    yum -y install https://packages.endpointdev.com/rhel/7/os/x86_64/endpoint-repo.x86_64.rpm && \
    yum -y install git

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

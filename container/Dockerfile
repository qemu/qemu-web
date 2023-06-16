FROM quay.io/centos/centos:stream9
EXPOSE 80
RUN dnf install -y httpd-core mod_ssl
COPY conf.d /etc/httpd/conf.d
CMD /usr/sbin/httpd -DNO_DETACH -DFOREGROUND


FROM stackbrew/ubuntu:precise
MAINTAINER Leif Walsh <leif.walsh@gmail.com>

RUN echo "deb [arch=amd64] http://s3.amazonaws.com/tokumx-debs precise main" > /etc/apt/sources.list.d/tokumx.list
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-key 505A7412
RUN apt-get update
RUN apt-get install -y openssh-server tokumx dnsmasq ntp curl wget build-essential git-core vim psmisc iptables dnsutils telnet nmap sudo
RUN mkdir /var/run/sshd 
ADD host_key.pub /tmp/host_key.pub
RUN mkdir -p /root/.ssh
RUN cat /tmp/host_key.pub >> /root/.ssh/authorized_keys

# dnsmasq configuration
RUN echo 'listen-address=127.0.0.1' >> /etc/dnsmasq.conf
RUN echo 'resolv-file=/etc/resolv.dnsmasq.conf' >> /etc/dnsmasq.conf
RUN echo 'conf-dir=/etc/dnsmasq.d' >> /etc/dnsmasq.conf
RUN echo 'user=root' >> /etc/dnsmasq.conf

RUN echo 'nameserver 8.8.8.8' >> /etc/resolv.dnsmasq.conf
RUN echo 'nameserver 8.8.4.4' >> /etc/resolv.dnsmasq.conf

EXPOSE 22
EXPOSE 27017
VOLUME /etc/dnsmasq.d
CMD service dnsmasq start && /usr/sbin/sshd -D

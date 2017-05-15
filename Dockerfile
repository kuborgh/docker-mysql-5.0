FROM ubuntu:12.04

ARG uid=1000
ARG gid=1000

# ensure user exists
RUN addgroup --gid $gid --system mysql \
	&& adduser --uid $uid --disabled-password --system --gid $gid mysql

RUN apt-get update &&\
    apt-get -y --no-install-recommends install ca-certificates wget && \
    wget https://downloads.mysql.com/archives/get/file/mysql-5.0.96-linux-x86_64-glibc23.tar.gz -O mysql.tar.gz && \
    mkdir -p /mysql && \
    tar -xzf mysql.tar.gz --no-same-owner -C /mysql --strip-components=1 && \
    apt-get -y remove wget && \
    apt-get -y autoremove && \
    apt-get clean

COPY my.cnf /etc/

COPY entrypoint.sh /mysql
ENTRYPOINT ["/mysql/entrypoint.sh"]

EXPOSE 3306
WORKDIR /mysql
CMD ["/mysql/bin/mysqld_safe", "--user=mysql"]

FROM ubuntu:18.04

RUN mkdir /docker \
 && apt-get update \
 && apt-get install --assume-yes \
      ansible \
      sudo

COPY setup-ubuntu/ /docker/setup/
RUN /docker/setup/setup.sh

COPY config/ /docker/config/
RUN /docker/config/config.sh

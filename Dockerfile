FROM python:latest

RUN apt-get clean
# Kubectl
RUN curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
RUN echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list


RUN apt-get update

RUN apt-get install -y \
  apt-transport-https \
  bash \
  coreutils \
  curl \
  git \
  groff \
  jq \
  kubectl=1.19.13-00 \
  less \
  make \
  python3 \
  tar \
  unzip \
  wget \
  zip \
  ca-certificates \
  gnupg-agent \
  software-properties-common \
  vim \
  vim-tiny \
  autojump \
  netcat \
  tig


# Docker
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
RUN apt-key fingerprint 0EBFCD88
RUN add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"

RUN apt-get update
RUN apt-get install -y docker-ce docker-ce-cli containerd.io

RUN pip3 install --upgrade pip awscli

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install

RUN wget https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb
RUN dpkg -i session-manager-plugin.deb
RUN rm session-manager-plugin.deb

ENV TERRAFORM_VERSION 1.1.8
ENV TERRAFORM_CHECKSUM fbd37c1ec3d163f493075aa0fa85147e7e3f88dd98760ee7af7499783454f4c5

RUN wget --quiet https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
  && (echo "${TERRAFORM_CHECKSUM} terraform_${TERRAFORM_VERSION}_linux_amd64.zip" | sha256sum --check ) \
  && unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
  && mv terraform /usr/bin \
  && rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip

ENV TFLINT_VERSION v0.24.1
ENV TFLINT_CHECKSUM 2dbe3b423f5d3e0bb458d51761c97d51a4fd6c3d7bd1efd87c4aa3dc5199e7b2

RUN wget --quiet https://github.com/terraform-linters/tflint/releases/download/${TFLINT_VERSION}/tflint_linux_amd64.zip \
  && (echo "${TFLINT_CHECKSUM} tflint_linux_amd64.zip" | sha256sum --check ) \
  && unzip tflint_linux_amd64.zip \
  && mv tflint /usr/bin \
  && rm tflint_linux_amd64.zip

COPY requirements.txt ./requirements.txt
RUN pip3 install -v -r requirements.txt

RUN git clone https://github.com/theserverlessway/awsinfo.git /awsinfo
RUN ln -s /awsinfo/scripts/awsinfo.bash /usr/local/bin/awsinfo
RUN awsinfo complete > /root/.awsinfo_completion

RUN curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
RUN mv /tmp/eksctl /usr/local/bin

RUN git clone https://github.com/toniblyx/prowler.git /prowler
ENV PATH="/prowler:${PATH}"

COPY bashrc /root/bashrc
RUN tr -d '\r' < /root/bashrc > /root/.bashrc && rm /root/bashrc
COPY gitconfig /root/.gitconfig

RUN git config --global credential.helper '!aws codecommit credential-helper $@'
RUN git config --global credential.UseHttpPath true

RUN git clone https://github.com/magicmonty/bash-git-prompt.git /bash-git-prompt --depth=1

CMD ["/bin/bash"]

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
  kubectl \
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
  netcat-openbsd \
  tig \
  dnsutils \
  sslscan


# Docker
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
RUN apt-key fingerprint 0EBFCD88
RUN add-apt-repository "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
RUN apt-get update
RUN apt-get install -y docker-ce docker-ce-cli containerd.io


# AWS and Python Tooling
RUN python -m ensurepip --upgrade
RUN pip3 install --upgrade pip awscli virtualenv aws-cdk-lib

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install

RUN wget https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_$(if [ $(dpkg --print-architecture) = "amd64" ] ; then echo "64bit" ; else echo "arm64" ; fi)/session-manager-plugin.deb
RUN dpkg -i session-manager-plugin.deb
RUN rm session-manager-plugin.deb

# CDK
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && apt-get install -y nodejs
RUN npm i -g aws-cdk

## Terraform

RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
RUN apt update && apt install terraform

COPY requirements.txt ./requirements.txt
RUN pip3 install -v -r requirements.txt

RUN git clone https://github.com/theserverlessway/awsinfo.git /awsinfo
RUN ln -s /awsinfo/scripts/awsinfo.bash /usr/local/bin/awsinfo
RUN awsinfo complete > /root/.awsinfo_completion

RUN git clone https://github.com/toniblyx/prowler.git /prowler
ENV PATH="/prowler:${PATH}"

RUN git clone https://github.com/OpenVPN/easy-rsa.git /easy-rsa
ENV PATH="/easy-rsa/easyrsa3:${PATH}"

COPY bashrc /root/bashrc
RUN tr -d '\r' < /root/bashrc > /root/.bashrc && rm /root/bashrc
COPY gitconfig /root/.gitconfig

RUN git config --global credential.helper '!aws codecommit credential-helper $@'
RUN git config --global credential.UseHttpPath true

RUN git clone https://github.com/magicmonty/bash-git-prompt.git /bash-git-prompt --depth=1

CMD ["/bin/bash"]

FROM python:latest

# Docker Repository
RUN install -m 0755 -d /etc/apt/keyrings
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
RUN chmod a+r /etc/apt/keyrings/docker.gpg
RUN echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# NodeJS Repository
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -

# Terraform Repository
RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list


RUN apt-get update && apt-get install -y \
  apt-transport-https \
  bash \
  coreutils \
  curl \
  git \
  groff \
  jq \
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
  sslscan \
  shellcheck \
  docker-ce \
  docker-ce-cli  \
  containerd.io  \
  docker-buildx-plugin  \
  docker-compose-plugin \
  nodejs \
  terraform \
  && apt-get clean && rm -rf /var/lib/apt/lists/*


# AWS and Python Tooling
RUN python -m ensurepip --upgrade
RUN pip3 install --upgrade pip awscli virtualenv aws-cdk-lib

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && rm awscliv2.zip && rm -fr ./aws

RUN wget https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_$(if [ $(dpkg --print-architecture) = "amd64" ] ; then echo "64bit" ; else echo "arm64" ; fi)/session-manager-plugin.deb && dpkg -i session-manager-plugin.deb && rm session-manager-plugin.deb

# CDK Install
RUN npm i -g aws-cdk

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

COPY ./scripts ./toolbox-scripts

CMD ["/bin/bash"]
